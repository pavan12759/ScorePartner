import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../main/main_navigation.dart';
import 'user_onboarding_screen.dart';

/// Email + Password authentication screen with rich aesthetics & animations
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ── Animation controllers ──
  late final AnimationController _staggerController;
  late final AnimationController _floatController;
  late final AnimationController _buttonPulseController;
  late final AnimationController _shimmerController;
  late final AnimationController _bgOrbController;
  late final AnimationController _ringController;

  // Staggered entrance animations
  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;

  late final Animation<double> _floatAnimation;
  late final Animation<double> _buttonScale;
  late final Animation<double> _shimmerAnimation;
  late final Animation<double> _bgOrbAnimation;
  late final Animation<double> _ringRotation;

  static const int _itemCount = 8;

  @override
  void initState() {
    super.initState();
    Provider.of<AuthProvider>(context, listen: false).clearError();

    // ── Stagger controller (runs once) ──
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
        curve:
            Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
      ).drive(Tween<Offset>(
        begin: const Offset(0, 0.4),
        end: Offset.zero,
      ));
    });

    // ── Floating icon (continuous) ──
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _floatAnimation = CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(begin: -8, end: 8));

    // ── Button pulse ──
    _buttonPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _buttonScale = CurvedAnimation(
      parent: _buttonPulseController,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(begin: 1.0, end: 1.03));

    // ── Shimmer ──
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _shimmerAnimation =
        Tween<double>(begin: -1.0, end: 2.0).animate(_shimmerController);

    // ── Background orbs floating ──
    _bgOrbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _bgOrbAnimation =
        Tween<double>(begin: 0.0, end: 2 * math.pi).animate(_bgOrbController);

    // ── Rotating ring around icon ──
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _staggerController.dispose();
    _floatController.dispose();
    _buttonPulseController.dispose();
    _shimmerController.dispose();
    _bgOrbController.dispose();
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

  void _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (!_isLogin && password != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.signInWithEmailPassword(email, password,
          isSignUp: !_isLogin);

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _signInWithGoogle() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.signInWithGoogle();

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: ${e.toString()}')),
      );
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
          // ── Background gradient ──
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

          // ── Animated floating orbs in background ──
          AnimatedBuilder(
            animation: _bgOrbAnimation,
            builder: (context, _) {
              return CustomPaint(
                size: screenSize,
                painter: _FloatingOrbsPainter(
                  animationValue: _bgOrbAnimation.value,
                  primaryColor: AppTheme.primaryOrange,
                  isDark: isDark,
                ),
              );
            },
          ),

          // ── Decorative top-right circle ──
          Positioned(
            top: -60.h,
            right: -40.w,
            child: AnimatedBuilder(
              animation: _bgOrbAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    math.sin(_bgOrbAnimation.value * 0.5) * 10,
                    math.cos(_bgOrbAnimation.value * 0.3) * 8,
                  ),
                  child: child,
                );
              },
              child: Container(
                width: 180.w,
                height: 180.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryOrange.withOpacity(0.15),
                      AppTheme.primaryOrange.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Decorative bottom-left circle ──
          Positioned(
            bottom: -80.h,
            left: -60.w,
            child: AnimatedBuilder(
              animation: _bgOrbAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    math.cos(_bgOrbAnimation.value * 0.4) * 12,
                    math.sin(_bgOrbAnimation.value * 0.6) * 10,
                  ),
                  child: child,
                );
              },
              child: Container(
                width: 200.w,
                height: 200.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryOrange.withOpacity(0.12),
                      AppTheme.primaryOrange.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                // ── App bar ──
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
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
                        SizedBox(height: 8.h),

                        // ── 0. Animated floating icon with rotating ring ──
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
                                    // Rotating dashed ring
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
                                    // Inner gradient circle
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
                                      child: Icon(
                                        Icons.email_rounded,
                                        size: 40.sp,
                                        color: AppTheme.primaryOrange,
                                      ),
                                    ),
                                    // Small orbiting dot
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
                              _isLogin
                                  ? 'Welcome Back!'
                                  : 'Create Account',
                              key: ValueKey<bool>(_isLogin),
                              style: TextStyle(
                                fontSize: 30.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 6.h),

                        // ── 2. Subtitle with accent bar ──
                        _animatedItem(
                          2,
                          Row(
                            children: [
                              Container(
                                width: 4.w,
                                height: 20.h,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryOrange,
                                  borderRadius:
                                      BorderRadius.circular(2.r),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              AnimatedSwitcher(
                                duration:
                                    const Duration(milliseconds: 400),
                                child: Text(
                                  _isLogin
                                      ? 'Sign in to continue'
                                      : 'Sign up to get started',
                                  key: ValueKey<String>(_isLogin
                                      ? 'login_sub'
                                      : 'signup_sub'),
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 32.h),

                        // ── Glassmorphism card for form ──
                        _animatedItem(
                          3,
                          Container(
                            padding: EdgeInsets.all(20.w),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20.r),
                              color: (isDark
                                      ? Colors.white
                                      : Colors.white)
                                  .withOpacity(isDark ? 0.08 : 0.7),
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
                                      .withOpacity(isDark ? 0.05 : 0.08),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                                if (!isDark)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Email field
                                _buildTextField(
                                  controller: _emailController,
                                  hint: 'Enter your email',
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType:
                                      TextInputType.emailAddress,
                                  isDark: isDark,
                                ),
                                SizedBox(height: 16.h),

                                // Password field
                                _buildTextField(
                                  controller: _passwordController,
                                  hint: 'Enter password',
                                  prefixIcon: Icons.lock_outline,
                                  obscure: _obscurePassword,
                                  isDark: isDark,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: Colors.grey[500],
                                        size: 20.sp),
                                    onPressed: () => setState(() =>
                                        _obscurePassword =
                                            !_obscurePassword),
                                  ),
                                ),

                                // Confirm Password
                                AnimatedSize(
                                  duration:
                                      const Duration(milliseconds: 400),
                                  curve: Curves.easeInOutCubic,
                                  child: !_isLogin
                                      ? Padding(
                                          padding: EdgeInsets.only(
                                              top: 16.h),
                                          child: AnimatedOpacity(
                                            opacity:
                                                _isLogin ? 0.0 : 1.0,
                                            duration: const Duration(
                                                milliseconds: 350),
                                            child: _buildTextField(
                                              controller:
                                                  _confirmPasswordController,
                                              hint: 'Confirm password',
                                              prefixIcon:
                                                  Icons.lock_outline,
                                              obscure:
                                                  _obscureConfirmPassword,
                                              isDark: isDark,
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                    _obscureConfirmPassword
                                                        ? Icons
                                                            .visibility_off_rounded
                                                        : Icons
                                                            .visibility_rounded,
                                                    color:
                                                        Colors.grey[500],
                                                    size: 20.sp),
                                                onPressed: () =>
                                                    setState(() =>
                                                        _obscureConfirmPassword =
                                                            !_obscureConfirmPassword),
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),

                                // Error message
                                AnimatedSize(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  child: errorMessage != null
                                      ? Padding(
                                          padding: EdgeInsets.only(
                                              top: 16.h),
                                          child:
                                              TweenAnimationBuilder<double>(
                                            tween: Tween(
                                                begin: 0.0, end: 1.0),
                                            duration: const Duration(
                                                milliseconds: 500),
                                            curve: Curves.elasticOut,
                                            builder:
                                                (context, value, child) {
                                              return Transform.scale(
                                                scale: value,
                                                child: Opacity(
                                                    opacity: value.clamp(
                                                        0.0, 1.0),
                                                    child: child),
                                              );
                                            },
                                            child: Container(
                                              padding:
                                                  EdgeInsets.all(12.w),
                                              decoration: BoxDecoration(
                                                color: Colors.red
                                                    .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12.r),
                                                border: Border.all(
                                                    color: Colors.red
                                                        .withOpacity(
                                                            0.2)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        EdgeInsets.all(
                                                            4.w),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: Colors.red
                                                          .withOpacity(
                                                              0.15),
                                                      shape:
                                                          BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                        Icons
                                                            .error_outline,
                                                        color: Colors.red,
                                                        size: 16.sp),
                                                  ),
                                                  SizedBox(width: 10.w),
                                                  Expanded(
                                                    child: Text(
                                                        errorMessage,
                                                        style: TextStyle(
                                                          color:
                                                              Colors.red,
                                                          fontSize: 13.sp,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w500,
                                                        )),
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

                        SizedBox(height: 24.h),

                        // ── 5. Sign-In button ──
                        _animatedItem(
                          5,
                          ScaleTransition(
                            scale: _buttonScale,
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
                                          _shimmerAnimation.value,
                                          0.5),
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
                                onPressed: isLoading
                                    ? null
                                    : _handleEmailAuth,
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
                                                strokeWidth: 2.5))
                                    : AnimatedSwitcher(
                                        duration: const Duration(
                                            milliseconds: 300),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          key: ValueKey<String>(
                                              _isLogin
                                                  ? 'sign_in'
                                                  : 'sign_up'),
                                          children: [
                                            Text(
                                              _isLogin
                                                  ? 'Sign In'
                                                  : 'Sign Up',
                                              style: TextStyle(
                                                  fontSize: 17.sp,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  letterSpacing: 0.5),
                                            ),
                                            SizedBox(width: 8.w),
                                            Icon(
                                              Icons
                                                  .arrow_forward_rounded,
                                              size: 20.sp,
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 20.h),

                        // ── 6. Toggle Login/Signup ──
                        _animatedItem(
                          6,
                          Center(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _confirmPasswordController.clear();
                                  authProvider.clearError();
                                });
                              },
                              child: AnimatedSwitcher(
                                duration:
                                    const Duration(milliseconds: 400),
                                transitionBuilder:
                                    (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin:
                                            const Offset(0, 0.3),
                                        end: Offset.zero,
                                      ).animate(CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutBack,
                                      )),
                                      child: child,
                                    ),
                                  );
                                },
                                child: RichText(
                                  key: ValueKey<bool>(_isLogin),
                                  text: TextSpan(
                                    style: TextStyle(
                                        fontSize: 14.sp,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600]),
                                    children: [
                                      TextSpan(
                                          text: _isLogin
                                              ? "Don't have an account? "
                                              : "Already have an account? "),
                                      TextSpan(
                                        text: _isLogin
                                            ? 'Sign Up'
                                            : 'Sign In',
                                        style: TextStyle(
                                          color: AppTheme
                                              .primaryOrange,
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 16.h),

                        // ── 7. Divider + Google button ──
                        _animatedItem(
                          7,
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withOpacity(0.12),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16.w),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12.w,
                                          vertical: 4.h),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(
                                                20.r),
                                        color: (isDark
                                                ? Colors.white
                                                : Colors.black)
                                            .withOpacity(0.06),
                                      ),
                                      child: Text('OR',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[500]
                                                : Colors.grey[500],
                                            fontSize: 12.sp,
                                            fontWeight:
                                                FontWeight.w600,
                                            letterSpacing: 1.5,
                                          )),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withOpacity(0.12),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: isLoading
                                      ? null
                                      : _signInWithGoogle,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    padding: EdgeInsets.symmetric(
                                        vertical: 16.h),
                                    side: BorderSide(
                                        color: (isDark
                                                ? Colors.white
                                                : Colors.black)
                                            .withOpacity(0.1)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                16.r)),
                                    backgroundColor: (isDark
                                            ? Colors.white
                                            : Colors.white)
                                        .withOpacity(
                                            isDark ? 0.05 : 0.6),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 24.w,
                                        height: 24.w,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  6.r),
                                        ),
                                        child: Center(
                                          child: Text('G',
                                              style: TextStyle(
                                                fontSize: 18.sp,
                                                fontWeight:
                                                    FontWeight.w800,
                                                color: const Color(
                                                    0xFF4285F4),
                                              )),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Text('Continue with Google',
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight:
                                                FontWeight.w600,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 32.h),
                      ],
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

  // ── Premium styled text field ──
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[600] : Colors.grey[400],
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            margin: EdgeInsets.all(12.w),
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(prefixIcon,
                color: AppTheme.primaryOrange, size: 18.sp),
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.grey[50],
          contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w, vertical: 16.h),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(
                color: (isDark ? Colors.white : Colors.black)
                    .withOpacity(0.06),
              )),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(
                color: (isDark ? Colors.white : Colors.black)
                    .withOpacity(0.06),
              )),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide:
                  BorderSide(color: AppTheme.primaryOrange, width: 1.5)),
        ),
      ),
    );
  }
}

// ── Floating Orbs Background Painter ──
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

    // Orb 1
    final orb1X = size.width * 0.2 + math.sin(animationValue * 0.7) * 30;
    final orb1Y = size.height * 0.15 + math.cos(animationValue * 0.5) * 25;
    paint.color = primaryColor.withOpacity(isDark ? 0.06 : 0.08);
    canvas.drawCircle(Offset(orb1X, orb1Y), 50, paint);

    // Orb 2
    final orb2X =
        size.width * 0.85 + math.cos(animationValue * 0.4) * 20;
    final orb2Y =
        size.height * 0.35 + math.sin(animationValue * 0.6) * 30;
    paint.color = primaryColor.withOpacity(isDark ? 0.04 : 0.06);
    canvas.drawCircle(Offset(orb2X, orb2Y), 40, paint);

    // Orb 3
    final orb3X =
        size.width * 0.5 + math.sin(animationValue * 0.3) * 25;
    final orb3Y =
        size.height * 0.7 + math.cos(animationValue * 0.8) * 20;
    paint.color = primaryColor.withOpacity(isDark ? 0.05 : 0.07);
    canvas.drawCircle(Offset(orb3X, orb3Y), 35, paint);

    // Orb 4 (small)
    final orb4X =
        size.width * 0.15 + math.cos(animationValue * 0.9) * 15;
    final orb4Y =
        size.height * 0.55 + math.sin(animationValue * 0.4) * 18;
    paint.color = primaryColor.withOpacity(isDark ? 0.04 : 0.05);
    canvas.drawCircle(Offset(orb4X, orb4Y), 22, paint);

    // Orb 5 (tiny accent)
    final orb5X =
        size.width * 0.7 + math.sin(animationValue * 1.1) * 12;
    final orb5Y =
        size.height * 0.85 + math.cos(animationValue * 0.7) * 15;
    paint.color = primaryColor.withOpacity(isDark ? 0.06 : 0.09);
    canvas.drawCircle(Offset(orb5X, orb5Y), 18, paint);
  }

  @override
  bool shouldRepaint(covariant _FloatingOrbsPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
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
    final gapRatio = 0.4;

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
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
