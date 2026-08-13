import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../main/main_navigation.dart';
import 'user_onboarding_screen.dart';
import '../../widgets/auth/premium_otp_input.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _verificationId = '';
  bool _isOtpSent = false;
  final String _countryCode = '+91';

  // OTP specific state
  bool _isVerifying = false;
  bool _isSuccess = false;
  bool _hasError = false;
  Timer? _resendTimer;
  int _resendSeconds = 30;

  @override
  void initState() {
    super.initState();
    Provider.of<AuthProvider>(context, listen: false).clearError();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendSeconds = 30;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds == 0) {
        timer.cancel();
        setState(() {});
      } else {
        setState(() {
          _resendSeconds--;
        });
      }
    });
  }

  void _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    final fullNumber = '$_countryCode$phone';
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.signInWithPhone(fullNumber, (verificationId) {
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _hasError = false;
          _isSuccess = false;
          _isVerifying = false;
        });
        _startResendTimer();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _verifyOtp(String otp) async {
    if (otp.length != 6) return;
    
    setState(() {
      _isVerifying = true;
      _hasError = false;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.verifyOtp(_verificationId, otp);

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        setState(() {
          _isVerifying = false;
          _isSuccess = true;
        });

        // Wait for the success morph animation to play
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;

        if (authProvider.isFirstTimeUser) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const UserOnboardingScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainNavigation()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _hasError = true;
      });
      // Optionally reset error state after animation plays so it can shake again
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _hasError = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoading = authProvider.isLoading;
    final errorMessage = authProvider.errorMessage;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 48.h),
              Center(
                child: Container(
                  width: 80.w,
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_android,
                    size: 40.sp,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              ),
              SizedBox(height: 32.h),
              Text(
                _isOtpSent ? 'Verify your number' : 'Enter Phone Number',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                _isOtpSent
                    ? 'We\'ve sent a 6-digit verification code to'
                    : 'We will send you a 6-digit verification code',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              ),
              if (_isOtpSent) ...[
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      '$_countryCode ${_phoneController.text.replaceRange(0, _phoneController.text.length - 4, '•' * (_phoneController.text.length - 4))}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlack,
                          ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isOtpSent = false;
                          _resendTimer?.cancel();
                        });
                      },
                      child: Text(
                        'Change number',
                        style: TextStyle(
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 32.h),
              if (!_isOtpSent) ...[
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 16.h,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        _countryCode,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(fontSize: 16.sp),
                        decoration: InputDecoration(
                          hintText: 'Mobile Number',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 16.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Premium Animated OTP
                Center(
                  child: PremiumOtpInput(
                    onCompleted: _verifyOtp,
                    hasError: _hasError,
                    isSuccess: _isSuccess,
                    isVerifying: _isVerifying,
                    errorMessage: errorMessage,
                  ),
                ),
                SizedBox(height: 24.h),
                if (!_isVerifying && !_isSuccess)
                  Center(
                    child: TextButton(
                      onPressed: _resendSeconds == 0
                          ? () {
                              _sendOtp(); // Re-trigger send OTP logic
                            }
                          : null,
                      child: Text(
                        _resendSeconds == 0
                            ? 'Resend OTP'
                            : 'Resend code in 00:${_resendSeconds.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: _resendSeconds == 0
                              ? AppTheme.primaryOrange
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
              
              // Error message display for phone input state
              if (errorMessage != null && !_isOtpSent) ...[
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const Spacer(),
              if (!_isOtpSent)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            height: 24.h,
                            width: 24.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Get OTP',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}
