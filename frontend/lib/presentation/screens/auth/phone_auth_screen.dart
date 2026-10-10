import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../main/main_navigation.dart';
import 'user_onboarding_screen.dart';
import '../../widgets/auth/premium_otp_input.dart';

/// Phone authentication screen with premium aesthetics & animations
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with TickerProviderStateMixin {
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

  // ── Animation controllers ──
  late final AnimationController _staggerController;
  late final AnimationController _floatController;
  late final AnimationController _orbController;
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;
  late final AnimationController _ringController;

  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;
  late final Animation<double> _floatAnimation;
  late final Animation<double> _orbAnimation;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _shimmerAnimation;
  late final Animation<double> _ringRotation;

  static const int _itemCount = 7;

  @override
  void initState() {
    super.initState();
    Provider.of<AuthProvider>(context, listen: false).clearError();

    // ── Stagger entrance ──
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnimations = List.generate(_itemCount, (i) {
      final start = i / (_itemCount + 2);
      final end = (i + 2) / (_itemCount + 2);
      return CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
      ).drive(Tween<double>(begin: 0.0, end: 1.0));
    });

    _slideAnimations = List.generate(_itemCount, (i) {
      final start = i / (_itemCount + 2);
      final end = (i + 2) / (_itemCount + 2);
      return CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end.clamp(0.0, 1.0),
            curve: Curves.easeOutCubic),
      ).drive(Tween<Offset>(
        begin: const Offset(0, 0.4),
        end: Offset.zero,
      ));
    });

    // ── Floating icon ──
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _floatAnimation = CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(begin: -8, end: 8));

    // ── Background orbs ──
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _orbAnimation =
        Tween<double>(begin: 0.0, end: 2 * math.pi).animate(_orbController);

    // ── Button pulse ──
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(begin: 1.0, end: 1.03));

    // ── Shimmer ──
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _shimmerAnimation =
        Tween<double>(begin: -1.0, end: 2.0).animate(_shimmerController);

    // ── Rotating ring ──
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _ringRotation =
        Tween<double>(begin: 0.0, end: 2 * math.pi).animate(CurvedAnimation(
      parent: _ringController,
      curve: Curves.linear,
    ));

    _staggerController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _resendTimer?.cancel();
    _staggerController.dispose();
    _floatController.dispose();
    _orbController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  Widget _animatedItem(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(
        position: _slideAnimations[index],
        child: child,
      ),
    );
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
            MaterialPageRoute(
                builder: (context) => const UserOnboardingScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => const MainNavigation()),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1A1A2E),
                        const Color(0xFF16213E),
                        const Color(0xFF0F3460),
                      ]
                    : [
                        const Color(0xFFFFF8F0),
                        const Color(0xFFFFF0E0),
                        const Color(0xFFFFE8D0),
                      ],
              ),
            ),
          ),

          // ── Floating orbs background ──
          AnimatedBuilder(
            animation: _orbAnimation,
            builder: (context, _) {
              return CustomPaint(
                size: screenSize,
                painter: _FloatingOrbsPainter(
                  animationValue: _orbAnimation.value,
                  primaryColor: AppTheme.primaryOrange,
                  isDark: isDark,
                ),
              );
            },
          ),

          // ── Decorative blobs ──
          Positioned(
            top: -50.h,
            right: -30.w,
            child: AnimatedBuilder(
              animation: _orbAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    math.sin(_orbAnimation.value * 0.5) * 10,
                    math.cos(_orbAnimation.value * 0.3) * 8,
                  ),
                  child: child,
                );
              },
              child: Container(
                width: 160.w,
                height: 160.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppTheme.primaryOrange
                        .withOpacity(isDark ? 0.08 : 0.14),
                    AppTheme.primaryOrange.withOpacity(0.0),
                  ]),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -70.h,
            left: -50.w,
            child: AnimatedBuilder(
              animation: _orbAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    math.cos(_orbAnimation.value * 0.4) * 12,
                    math.sin(_orbAnimation.value * 0.6) * 10,
                  ),
                  child: child,
                );
              },
              child: Container(
                width: 180.w,
                height: 180.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppTheme.primaryOrange
                        .withOpacity(isDark ? 0.06 : 0.10),
                    AppTheme.primaryOrange.withOpacity(0.0),
                  ]),
                ),
              ),
            ),
          ),

          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                // ── Back button ──
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(Icons.arrow_back_ios_new,
                              size: 18.sp,
                              color:
                                  isDark ? Colors.white70 : Colors.black87),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable body ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 28.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 12.h),

                        // ── 0. Animated icon with rotating ring ──
                        _animatedItem(
                          0,
                          Center(
                            child: AnimatedBuilder(
                              animation: _floatAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset:
                                      Offset(0, _floatAnimation.value),
                                  child: child,
                                );
                              },
                              child: SizedBox(
                                width: 120.w,
                                height: 120.w,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Outer glow
                                    Container(
                                      width: 120.w,
                                      height: 120.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryOrange
                                                .withOpacity(0.25),
                                            blurRadius: 40,
                                            spreadRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Dashed ring
                                    AnimatedBuilder(
                                      animation: _ringRotation,
                                      builder: (context, child) {
                                        return Transform.rotate(
                                          angle: _ringRotation.value,
                                          child: child,
                                        );
                                      },
                                      child: CustomPaint(
                                        size: Size(110.w, 110.w),
                                        painter: _DashedCirclePainter(
                                          color: AppTheme.primaryOrange
                                              .withOpacity(0.3),
                                          strokeWidth: 2,
                                          dashCount: 20,
                                        ),
                                      ),
                                    ),
                                    // Inner circle
                                    Container(
                                      width: 88.w,
                                      height: 88.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.primaryOrange
                                                .withOpacity(0.18),
                                            AppTheme.primaryOrange
                                                .withOpacity(0.06),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: AppTheme.primaryOrange
                                              .withOpacity(0.15),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                            milliseconds: 500),
                                        transitionBuilder:
                                            (child, animation) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Icon(
                                          _isOtpSent
                                              ? Icons.sms_rounded
                                              : Icons
                                                  .phone_android_rounded,
                                          key: ValueKey<bool>(_isOtpSent),
                                          size: 40.sp,
                                          color: AppTheme.primaryOrange,
                                        ),
                                      ),
                                    ),
                                    // Orbiting dot
                                    AnimatedBuilder(
                                      animation: _ringRotation,
                                      builder: (context, _) {
                                        final angle =
                                            _ringRotation.value;
                                        final radius = 50.w;
                                        return Transform.translate(
                                          offset: Offset(
                                            math.cos(angle) * radius,
                                            math.sin(angle) * radius,
                                          ),
                                          child: Container(
                                            width: 8.w,
                                            height: 8.w,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color:
                                                  AppTheme.primaryOrange,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppTheme
                                                      .primaryOrange
                                                      .withOpacity(0.6),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 28.h),

                        // ── 1. Title ──
                        _animatedItem(
                          1,
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.08, 0),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutBack,
                                  )),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _isOtpSent
                                  ? 'Verify your number'
                                  : 'Enter Phone Number',
                              key: ValueKey<String>(
                                  _isOtpSent ? 'verify' : 'enter'),
                              style: TextStyle(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 8.h),

                        // ── 2. Subtitle with accent bar ──
                        _animatedItem(
                          2,
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4.w,
                                height: 20.h,
                                margin: EdgeInsets.only(top: 2.h),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryOrange,
                                  borderRadius:
                                      BorderRadius.circular(2.r),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 400),
                                  child: Text(
                                    _isOtpSent
                                        ? 'We\'ve sent a 6-digit code to'
                                        : 'We will send you a 6-digit verification code',
                                    key: ValueKey<String>(_isOtpSent
                                        ? 'otp_sub'
                                        : 'phone_sub'),
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      letterSpacing: 0.2,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Phone number display + change ──
                        if (_isOtpSent) ...[
                          SizedBox(height: 8.h),
                          _animatedItem(
                            2,
                            Padding(
                              padding: EdgeInsets.only(left: 14.w),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryOrange
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(8.r),
                                    ),
                                    child: Text(
                                      '$_countryCode ${_phoneController.text.replaceRange(0, _phoneController.text.length - 4, '•' * (_phoneController.text.length - 4))}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.sp,
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.deepBlack,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isOtpSent = false;
                                        _resendTimer?.cancel();
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 4.h),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppTheme.primaryOrange
                                              .withOpacity(0.4),
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.r),
                                      ),
                                      child: Text(
                                        'Change',
                                        style: TextStyle(
                                          color: AppTheme.primaryOrange,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 32.h),

                        // ── 3. Phone input or OTP input ──
                        if (!_isOtpSent) ...[
                          _animatedItem(
                            3,
                            Container(
                              padding: EdgeInsets.all(20.w),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(20.r),
                                color: (isDark
                                        ? Colors.white
                                        : Colors.white)
                                    .withOpacity(
                                        isDark ? 0.08 : 0.7),
                                border: Border.all(
                                  color: (isDark
                                          ? Colors.white
                                          : AppTheme.primaryOrange)
                                      .withOpacity(0.12),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryOrange
                                        .withOpacity(
                                            isDark ? 0.05 : 0.08),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.04),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Country code badge
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14.w,
                                      vertical: 14.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryOrange
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: AppTheme.primaryOrange
                                            .withOpacity(0.15),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          '🇮🇳',
                                          style:
                                              TextStyle(fontSize: 18.sp),
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          _countryCode,
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  // Phone input
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        letterSpacing: 1.2,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Mobile Number',
                                        hintStyle: TextStyle(
                                          color: isDark
                                              ? Colors.grey[600]
                                              : Colors.grey[400],
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 0,
                                        ),
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                          horizontal: 16.w,
                                          vertical: 14.h,
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? Colors.white
                                                .withOpacity(0.06)
                                            : Colors.grey[50],
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12.r),
                                          borderSide: BorderSide(
                                            color: (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withOpacity(0.06),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12.r),
                                          borderSide: BorderSide(
                                            color: (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withOpacity(0.06),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12.r),
                                          borderSide: BorderSide(
                                            color:
                                                AppTheme.primaryOrange,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          // ── OTP input ──
                          _animatedItem(
                            3,
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12.w, vertical: 20.h),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(20.r),
                                color: (isDark
                                        ? Colors.white
                                        : Colors.white)
                                    .withOpacity(
                                        isDark ? 0.08 : 0.7),
                                border: Border.all(
                                  color: (isDark
                                          ? Colors.white
                                          : AppTheme.primaryOrange)
                                      .withOpacity(0.12),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryOrange
                                        .withOpacity(
                                            isDark ? 0.05 : 0.08),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: PremiumOtpInput(
                                  onCompleted: _verifyOtp,
                                  hasError: _hasError,
                                  isSuccess: _isSuccess,
                                  isVerifying: _isVerifying,
                                  errorMessage: errorMessage,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 20.h),

                          // ── Resend timer ──
                          if (!_isVerifying && !_isSuccess)
                            _animatedItem(
                              4,
                              Center(
                                child: TextButton(
                                  onPressed: _resendSeconds == 0
                                      ? () => _sendOtp()
                                      : null,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_resendSeconds > 0) ...[
                                        // Timer ring
                                        SizedBox(
                                          width: 22.w,
                                          height: 22.w,
                                          child: Stack(
                                            alignment:
                                                Alignment.center,
                                            children: [
                                              CircularProgressIndicator(
                                                value: _resendSeconds /
                                                    30,
                                                strokeWidth: 2,
                                                backgroundColor:
                                                    Colors.grey
                                                        .withOpacity(
                                                            0.2),
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                  AppTheme
                                                      .primaryOrange
                                                      .withOpacity(
                                                          0.5),
                                                ),
                                              ),
                                              Text(
                                                '$_resendSeconds',
                                                style: TextStyle(
                                                  fontSize: 9.sp,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: isDark
                                                      ? Colors
                                                          .grey[400]
                                                      : Colors
                                                          .grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          'Resend code in 00:${_resendSeconds.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[500]
                                                : Colors.grey[500],
                                            fontWeight:
                                                FontWeight.w500,
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ] else ...[
                                        Icon(
                                          Icons.refresh_rounded,
                                          size: 18.sp,
                                          color:
                                              AppTheme.primaryOrange,
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          'Resend OTP',
                                          style: TextStyle(
                                            color: AppTheme
                                                .primaryOrange,
                                            fontWeight:
                                                FontWeight.w700,
                                            fontSize: 15.sp,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],

                        // ── Error message ──
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: errorMessage != null && !_isOtpSent
                              ? Padding(
                                  padding: EdgeInsets.only(top: 16.h),
                                  child:
                                      TweenAnimationBuilder<double>(
                                    tween:
                                        Tween(begin: 0.0, end: 1.0),
                                    duration: const Duration(
                                        milliseconds: 500),
                                    curve: Curves.elasticOut,
                                    builder:
                                        (context, value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: Opacity(
                                            opacity:
                                                value.clamp(0.0, 1.0),
                                            child: child),
                                      );
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: Colors.red
                                            .withOpacity(0.08),
                                        borderRadius:
                                            BorderRadius.circular(
                                                12.r),
                                        border: Border.all(
                                            color: Colors.red
                                                .withOpacity(0.2)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding:
                                                EdgeInsets.all(4.w),
                                            decoration: BoxDecoration(
                                              color: Colors.red
                                                  .withOpacity(0.15),
                                              shape:
                                                  BoxShape.circle,
                                            ),
                                            child: Icon(
                                                Icons.error_outline,
                                                color: Colors.red,
                                                size: 16.sp),
                                          ),
                                          SizedBox(width: 10.w),
                                          Expanded(
                                            child: Text(
                                              errorMessage,
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 13.sp,
                                                fontWeight:
                                                    FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Bottom CTA button ──
                if (!_isOtpSent)
                  Padding(
                    padding: EdgeInsets.fromLTRB(28.w, 0, 28.w, 24.h),
                    child: _animatedItem(
                      5,
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (context, child) {
                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(16.r),
                                gradient: LinearGradient(
                                  begin: Alignment(
                                      -1.0 +
                                          _shimmerAnimation.value,
                                      -0.5),
                                  end: Alignment(
                                      _shimmerAnimation.value, 0.5),
                                  colors: [
                                    AppTheme.primaryOrange,
                                    const Color(0xFFFF6B35),
                                    const Color(0xFFFFAB76),
                                    const Color(0xFFFF6B35),
                                    AppTheme.primaryOrange,
                                  ],
                                  stops: const [
                                    0.0,
                                    0.25,
                                    0.5,
                                    0.75,
                                    1.0
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryOrange
                                        .withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                    spreadRadius: -2,
                                  ),
                                  BoxShadow(
                                    color: AppTheme.primaryOrange
                                        .withOpacity(0.2),
                                    blurRadius: 40,
                                    offset: const Offset(0, 16),
                                    spreadRadius: -4,
                                  ),
                                ],
                              ),
                              child: child,
                            );
                          },
                          child: ElevatedButton(
                            onPressed:
                                isLoading ? null : _sendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  vertical: 18.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16.r)),
                            ),
                            child: isLoading
                                ? SizedBox(
                                    height: 24.h,
                                    width: 24.w,
                                    child:
                                        const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Get OTP',
                                        style: TextStyle(
                                          fontSize: 17.sp,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20.sp,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating Orbs Painter ──
class _FloatingOrbsPainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;
  final bool isDark;

  _FloatingOrbsPainter({
    required this.animationValue,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final orbs = [
      [0.2, 0.12, 0.7, 0.5, 45.0, isDark ? 0.05 : 0.07],
      [0.85, 0.3, 0.4, 0.6, 35.0, isDark ? 0.04 : 0.06],
      [0.5, 0.65, 0.3, 0.8, 30.0, isDark ? 0.04 : 0.05],
      [0.12, 0.5, 0.9, 0.4, 20.0, isDark ? 0.03 : 0.04],
      [0.75, 0.82, 1.1, 0.7, 16.0, isDark ? 0.05 : 0.07],
    ];

    for (final orb in orbs) {
      final x = size.width * (orb[0] as double) +
          math.sin(animationValue * (orb[2] as double)) * 25;
      final y = size.height * (orb[1] as double) +
          math.cos(animationValue * (orb[3] as double)) * 20;
      paint.color = primaryColor.withOpacity(orb[5] as double);
      canvas.drawCircle(Offset(x, y), orb[4] as double, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingOrbsPainter old) =>
      old.animationValue != animationValue;
}

// ── Dashed Circle Painter ──
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final dashAngle = (2 * math.pi) / dashCount;
    const gapRatio = 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapRatio);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) =>
      old.color != color;
}
