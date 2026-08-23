const express = require('express');
const { RtcTokenBuilder, RtcRole } = require('agora-token');
const router = express.Router();
const { auth } = require('../middleware/auth');

/**
 * POST /api/agora/token
 * Body: { channelName: string, uid?: number, role?: 'publisher' | 'subscriber' }
 * Returns a fresh Agora RTC token valid for AGORA_TOKEN_EXPIRE_SECONDS (default 24 hours)
 *
 * The App Certificate never leaves the server — Flutter only receives the token.
 */
router.post('/token', auth, (req, res) => {
  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;

  // ── Validate server config ──────────────────────────────────────────────────
  if (!appId || !appCertificate || appCertificate === 'your-agora-app-certificate-here') {
    console.error('❌ AGORA_APP_CERTIFICATE is not configured in .env');
    return res.status(500).json({
      error: 'Video streaming not configured. Contact the admin.',
    });
  }

  const { channelName, uid = 0, role = 'publisher' } = req.body;

  if (!channelName || typeof channelName !== 'string' || channelName.trim().length === 0) {
    return res.status(400).json({ error: 'channelName is required.' });
  }

  const agoraRole = role === 'subscriber'
    ? RtcRole.SUBSCRIBER
    : RtcRole.PUBLISHER;

  const expireSeconds = parseInt(process.env.AGORA_TOKEN_EXPIRE_SECONDS || '86400', 10);
  const currentTime = Math.floor(Date.now() / 1000);
  const privilegeExpireTime = currentTime + expireSeconds;

  try {
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName.trim(),
      uid,
      agoraRole,
      privilegeExpireTime,
      privilegeExpireTime,
    );

    console.log(
      `🎥 Agora token generated for user ${req.user ? req.user.uid : 'guest'} | channel=${channelName} | role=${role} | expires in ${expireSeconds}s`,
    );

    return res.json({
      token,
      appId,                          // App ID is public — safe to send to Flutter
      channelName: channelName.trim(),
      uid,
      expiresAt: privilegeExpireTime, // Unix timestamp so Flutter can refresh proactively
    });
  } catch (err) {
    console.error('Agora token generation error:', err.message);
    return res.status(500).json({ error: 'Failed to generate stream token.' });
  }
});

/**
 * GET /api/agora/status
 * Returns whether the Agora streaming feature is properly configured.
 */
router.get('/status', auth, (req, res) => {
  const configured =
    !!process.env.AGORA_APP_ID &&
    !!process.env.AGORA_APP_CERTIFICATE &&
    process.env.AGORA_APP_CERTIFICATE !== 'your-agora-app-certificate-here';

  res.json({
    available: configured,
    message: configured ? 'Video streaming is ready.' : 'Video streaming not configured.',
  });
});

module.exports = router;
