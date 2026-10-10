/**
 * MSG91 OTP Service for ScorePartner
 * Supports both MSG91 OTP Widget (Widget ID) & Standard SendOTP API v5
 */

// Helper to normalize phone number to MSG91 format (e.g., 919876543210)
function normalizePhoneForMsg91(phoneNumber) {
  if (!phoneNumber) return '';
  let digits = phoneNumber.toString().replace(/\D/g, '');

  // If starts with 0 and length is 11, strip leading 0
  if (digits.startsWith('0') && digits.length === 11) {
    digits = digits.substring(1);
  }

  // If 10 digits (India standard mobile), prepend 91
  if (digits.length === 10) {
    digits = '91' + digits;
  }

  return digits;
}

// Helper to format phone number to E.164 (e.g., +919876543210) for Firebase & DB
function formatPhoneE164(phoneNumber) {
  const normalized = normalizePhoneForMsg91(phoneNumber);
  return normalized ? `+${normalized}` : '';
}

class Msg91Service {
  constructor() {
    this.authKey = process.env.MSG91_AUTH_KEY;
    this.widgetId = process.env.MSG91_WIDGET_ID || '366a6a664548373532393930';
    this.templateId = process.env.MSG91_TEMPLATE_ID;
    this.otpLength = parseInt(process.env.MSG91_OTP_LENGTH || '6', 10);
    this.otpExpiry = parseInt(process.env.MSG91_OTP_EXPIRY || '10', 10); // in minutes
    // Cache to hold reqId mapped to phone number for Widget API flow
    this.pendingWidgetRequests = new Map();
  }

  /**
   * Check if MSG91 is properly configured with live credentials
   */
  isConfigured() {
    const key = process.env.MSG91_AUTH_KEY || this.authKey;
    const widget = process.env.MSG91_WIDGET_ID || this.widgetId;
    const template = process.env.MSG91_TEMPLATE_ID || this.templateId;
    return Boolean(
      key &&
      !key.includes('your_msg91') &&
      (widget || template)
    );
  }

  /**
   * Send OTP via MSG91 (using Widget API or Template API)
   * @param {string} phoneNumber - User's phone number
   * @returns {Promise<{ success: boolean, message: string, devMode?: boolean, reqId?: string }>}
   */
  async sendOtp(phoneNumber) {
    const mobile = normalizePhoneForMsg91(phoneNumber);
    if (!mobile || mobile.length < 10) {
      throw new Error('Please provide a valid phone number');
    }

    // Dev/Test mode fallback if MSG91 keys are not configured yet
    if (!this.isConfigured()) {
      console.warn('⚠️ [MSG91] Live credentials not set in .env.');
      console.warn(`⚠️ [MSG91 DEV MODE] Use test OTP: 123456 for mobile: ${mobile}`);
      return {
        success: true,
        message: 'OTP sent (Dev mode: use 123456)',
        devMode: true,
      };
    }

    try {
      const authKey = process.env.MSG91_AUTH_KEY || this.authKey;
      const templateId = (process.env.MSG91_TEMPLATE_ID || this.templateId || '').trim();
      const widgetId = (process.env.MSG91_WIDGET_ID || this.widgetId || '').trim();

      // ── Method A: Standard / Custom Template API (Used when MSG91_TEMPLATE_ID is provided) ──
      if (templateId) {
        const url = `https://control.msg91.com/api/v5/otp?template_id=${encodeURIComponent(
          templateId
        )}&mobile=${encodeURIComponent(mobile)}&otp_length=${this.otpLength}&otp_expiry=${this.otpExpiry}`;

        const response = await fetch(url, {
          method: 'POST',
          headers: {
            authkey: authKey,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            template_id: templateId,
            mobile: mobile,
            otp_length: this.otpLength,
            otp_expiry: this.otpExpiry,
          }),
        });

        const data = await response.json().catch(() => ({}));
        if (!response.ok || data.type === 'error') {
          const errorMsg = data.message || `Failed to send OTP (Status: ${response.status})`;
          console.error('❌ MSG91 Template sendOtp error:', errorMsg);
          throw new Error(errorMsg);
        }

        console.log(`✅ [MSG91 Template] Custom OTP sent successfully to ${mobile} (Template: ${templateId})`);
        return {
          success: true,
          message: data.message || 'OTP sent successfully',
        };
      }

      // ── Method B: MSG91 Widget API (Default when no specific template ID is set) ──
      if (widgetId) {
        const url = 'https://control.msg91.com/api/v5/widget/sendOtpMobile';
        const response = await fetch(url, {
          method: 'POST',
          headers: {
            authkey: authKey,
            'Content-Type': 'application/json',
            Accept: 'application/json',
          },
          body: JSON.stringify({
            widgetId,
            identifier: mobile,
          }),
        });

        const data = await response.json().catch(() => ({}));
        if (!response.ok || data.type === 'error') {
          const errorMsg = data.message || `Failed to send OTP (Status: ${response.status})`;
          console.error('❌ MSG91 Widget sendOtp error:', errorMsg);
          throw new Error(errorMsg);
        }

        // Widget API returns reqId in data.message
        const reqId = typeof data.message === 'string' ? data.message : data.reqId || '';
        if (reqId) {
          this.pendingWidgetRequests.set(mobile, reqId);
        }

        console.log(`✅ [MSG91 Widget] OTP sent successfully to ${mobile} (ReqId: ${reqId})`);
        return {
          success: true,
          message: 'OTP sent successfully',
          reqId,
        };
      }
      return {
        success: true,
        message: data.message || 'OTP sent successfully',
      };
    } catch (error) {
      console.error('❌ MSG91 sendOtp exception:', error.message);
      throw error;
    }
  }

  /**
   * Verify OTP via MSG91
   * @param {string} phoneNumber - User's phone number
   * @param {string} otp - OTP entered by user
   * @param {string} [customReqId] - Optional reqId from Widget API
   * @returns {Promise<{ success: boolean, message: string }>}
   */
  async verifyOtp(phoneNumber, otp, customReqId) {
    const mobile = normalizePhoneForMsg91(phoneNumber);
    if (!mobile || !otp) {
      throw new Error('Phone number and OTP are required');
    }

    // Dev/Test mode verification
    if (!this.isConfigured()) {
      if (otp === '123456' || otp === '000000') {
        console.log(`✅ [MSG91 DEV MODE] OTP verified successfully for ${mobile}`);
        return {
          success: true,
          message: 'OTP verified successfully (Dev Mode)',
        };
      }
      throw new Error('Invalid OTP. (Dev mode: use 123456)');
    }

    try {
      const authKey = process.env.MSG91_AUTH_KEY || this.authKey;
      const templateId = (process.env.MSG91_TEMPLATE_ID || this.templateId || '').trim();
      const widgetId = (process.env.MSG91_WIDGET_ID || this.widgetId || '').trim();

      // ── Method A: Standard Template Verify API (When MSG91_TEMPLATE_ID is used) ──
      if (templateId) {
        const url = `https://control.msg91.com/api/v5/otp/verify?otp=${encodeURIComponent(
          otp
        )}&mobile=${encodeURIComponent(mobile)}`;

        const response = await fetch(url, {
          method: 'GET',
          headers: {
            authkey: authKey,
          },
        });

        const data = await response.json().catch(() => ({}));
        if (!response.ok || data.type === 'error') {
          const errorMsg = data.message || 'Invalid or expired OTP';
          console.warn(`❌ [MSG91 Template] OTP verification failed for ${mobile}:`, errorMsg);
          throw new Error(errorMsg);
        }

        console.log(`✅ [MSG91 Template] OTP verified successfully for ${mobile}`);
        return {
          success: true,
          message: data.message || 'OTP verified successfully',
        };
      }

      // ── Method B: MSG91 Widget Verify API ──
      if (widgetId) {
        const reqId = customReqId || this.pendingWidgetRequests.get(mobile);
        const url = 'https://control.msg91.com/api/v5/widget/verifyOtp';

        const payload = {
          widgetId,
          otp: otp.trim(),
        };
        if (reqId) {
          payload.reqId = reqId;
          payload.request_id = reqId;
        }

        const response = await fetch(url, {
          method: 'POST',
          headers: {
            authkey: authKey,
            'Content-Type': 'application/json',
            Accept: 'application/json',
          },
          body: JSON.stringify(payload),
        });

        const data = await response.json().catch(() => ({}));
        if (!response.ok || data.type === 'error') {
          const errorMsg = data.message || 'Invalid or expired OTP';
          console.warn(`❌ [MSG91 Widget] OTP verification failed for ${mobile}:`, errorMsg);
          throw new Error(errorMsg);
        }

        console.log(`✅ [MSG91 Widget] OTP verified successfully for ${mobile}`);
        return {
          success: true,
          message: 'OTP verified successfully',
        };
      }
    } catch (error) {
      console.error('❌ MSG91 verifyOtp exception:', error.message);
      throw error;
    }
  }

  /**
   * Resend / Retry OTP via MSG91
   * @param {string} phoneNumber - User's phone number
   * @param {'text' | 'voice'} retryType - Retry channel (text or voice)
   * @returns {Promise<{ success: boolean, message: string }>}
   */
  async resendOtp(phoneNumber, retryType = 'text') {
    const mobile = normalizePhoneForMsg91(phoneNumber);
    if (!mobile) {
      throw new Error('Please provide a valid phone number');
    }

    // Dev/Test mode fallback
    if (!this.isConfigured()) {
      console.warn(`⚠️ [MSG91 DEV MODE] Resend OTP for ${mobile}. Use 123456.`);
      return {
        success: true,
        message: 'OTP resent (Dev mode: use 123456)',
        devMode: true,
      };
    }

    try {
      const authKey = process.env.MSG91_AUTH_KEY || this.authKey;
      const templateId = (process.env.MSG91_TEMPLATE_ID || this.templateId || '').trim();
      const widgetId = (process.env.MSG91_WIDGET_ID || this.widgetId || '').trim();

      // ── Method A: Standard Template Retry API (When MSG91_TEMPLATE_ID is used) ──
      if (templateId) {
        const url = `https://control.msg91.com/api/v5/otp/retry?authkey=${encodeURIComponent(
          authKey
        )}&mobile=${encodeURIComponent(mobile)}&retrytype=${encodeURIComponent(retryType)}`;

        const response = await fetch(url, {
          method: 'GET',
          headers: {
            authkey: authKey,
          },
        });

        const data = await response.json().catch(() => ({}));
        if (!response.ok || data.type === 'error') {
          const errorMsg = data.message || 'Failed to resend OTP';
          console.error('❌ MSG91 Template resendOtp error:', errorMsg);
          throw new Error(errorMsg);
        }

        console.log(`✅ [MSG91 Template] OTP resent successfully to ${mobile}`);
        return {
          success: true,
          message: data.message || 'OTP resent successfully',
        };
      }

      // ── Method B: MSG91 Widget Retry API ──
      if (widgetId) {
        const reqId = this.pendingWidgetRequests.get(mobile);
        const url = 'https://control.msg91.com/api/v5/widget/retryOtp';

        const response = await fetch(url, {
          method: 'POST',
          headers: {
            authkey: authKey,
            'Content-Type': 'application/json',
            Accept: 'application/json',
          },
          body: JSON.stringify({
            widgetId,
            reqId,
            retryChannel: retryType === 'voice' ? 4 : (retryType === 'whatsapp' ? 12 : 11),
          }),
        });

        const data = await response.json().catch(() => ({}));
        if (!response.ok || data.type === 'error') {
          const errorMsg = data.message || 'Failed to resend OTP';
          console.error('❌ MSG91 Widget retryOtp error:', errorMsg);
          throw new Error(errorMsg);
        }

        console.log(`✅ [MSG91 Widget] OTP resent successfully to ${mobile}`);
        return {
          success: true,
          message: data.message || 'OTP resent successfully',
        };
      }
    } catch (error) {
      console.error('❌ MSG91 resendOtp exception:', error.message);
      throw error;
    }
  }

  /**
   * Verify JWT access token generated by MSG91 Client SDK (sendotp_flutter_sdk)
   * @param {string} accessToken - JWT token returned by MSG91 Flutter Widget
   * @returns {Promise<{ success: boolean, mobile: string }>}
   */
  async verifyAccessToken(accessToken) {
    if (!accessToken) {
      throw new Error('Access token is required');
    }

    if (!this.isConfigured()) {
      return {
        success: true,
        mobile: '919876543210',
      };
    }

    try {
      const authKey = process.env.MSG91_AUTH_KEY || this.authKey;
      const url = 'https://control.msg91.com/api/v5/widget/verifyAccessToken';

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          authkey: authKey,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({
          authkey: authKey,
          'access-token': accessToken,
        }),
      });

      const data = await response.json().catch(() => ({}));
      if (!response.ok || data.type === 'error') {
        const errorMsg = data.message || 'Failed to verify access token';
        console.error('❌ MSG91 verifyAccessToken error:', errorMsg);
        throw new Error(errorMsg);
      }

      const mobile = data.message || '';
      console.log(`✅ [MSG91] Access token verified successfully for mobile: ${mobile}`);
      return {
        success: true,
        mobile,
      };
    } catch (error) {
      console.error('❌ MSG91 verifyAccessToken exception:', error.message);
      throw error;
    }
  }
}

module.exports = {
  msg91Service: new Msg91Service(),
  normalizePhoneForMsg91,
  formatPhoneE164,
};
