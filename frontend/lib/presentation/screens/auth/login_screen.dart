import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'phone_auth_screen.dart';
import 'email_auth_screen.dart';
import '../main/main_navigation.dart';
import 'user_onboarding_screen.dart';

/// Login screen with 3 options: Mobile, Email, Google
/// Premium aesthetic with staggered animations and rich visuals
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ──
  late final AnimationController _staggerController;
  late final AnimationController _floatController;
  late final AnimationController _orbController;
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;

  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;
  late final Animation<double> _floatAnimation;
  late final Animation<double> _orbAnimation;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _shimmerAnimation;

  // 0: logo, 1: title, 2: subtitle, 3: mobile btn, 4: email btn, 5: google btn, 6: terms
  static const int _itemCount = 7;

  @override
  void initState() {
    super.initState();

    // ── Stagger (runs once) ──
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
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
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ));
    });

    // ── Floating logo ──
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _floatAnimation = CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(begin: -10, end: 10));

    // ── Background orbs ──
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _orbAnimation =
        Tween<double>(begin: 0.0, end: 2 * math.pi).animate(_orbController);

    // ── Button pulse ──
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(begin: 1.0, end: 1.035));

    // ── Button shimmer ──
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _shimmerAnimation =
        Tween<double>(begin: -1.0, end: 2.0).animate(_shimmerController);

    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _floatController.dispose();
    _orbController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF1A1A2E),
                        const Color(0xFF16213E),
                        const Color(0xFF0F3460),
                      ]
                    : [
                        const Color(0xFFFFFBF5),
                        const Color(0xFFFFF5EB),
                        const Color(0xFFFFEDD8),
                      ],
              ),
            ),
          ),

          // ── Animated floating orbs ──
          AnimatedBuilder(
            animation: _orbAnimation,
            builder: (context, _) {
              return CustomPaint(
                size: screenSize,
                painter: _OrbsPainter(
                  animValue: _orbAnimation.value,
                  color: AppTheme.primaryOrange,
                  isDark: isDark,
                ),
              );
            },
          ),

          // ── Decorative top-right blob ──
          Positioned(
            top: -50.h,
            right: -30.w,
            child: AnimatedBuilder(
              animation: _orbAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    math.sin(_orbAnimation.value * 0.5) * 12,
                    math.cos(_orbAnimation.value * 0.3) * 10,
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
                    AppTheme.primaryOrange.withOpacity(isDark ? 0.08 : 0.12),
                    AppTheme.primaryOrange.withOpacity(0.0),
                  ]),
                ),
              ),
            ),
          ),

          // ── Decorative bottom-left blob ──
          Positioned(
            bottom: -70.h,
            left: -50.w,
            child: AnimatedBuilder(
              animation: _orbAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    math.cos(_orbAnimation.value * 0.4) * 15,
                    math.sin(_orbAnimation.value * 0.6) * 12,
                  ),
                  child: child,
                );
              },
              child: Container(
                width: 200.w,
                height: 200.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppTheme.primaryOrange.withOpacity(isDark ? 0.06 : 0.10),
                    AppTheme.primaryOrange.withOpacity(0.0),
                  ]),
                ),
              ),
            ),
          ),

          // ── Main content ──
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── 0. Animated floating logo ──
                  _animatedItem(
                    0,
                    AnimatedBuilder(
                      animation: _floatAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _floatAnimation.value),
                          child: child,
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow
                          Container(
                            width: 130.w,
                            height: 130.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryOrange
                                      .withOpacity(0.2),
                                  blurRadius: 50,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          // Logo container with gradient
                          Container(
                            width: 100.w,
                            height: 100.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28.r),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.primaryOrange.withOpacity(0.15),
                                  AppTheme.primaryOrange.withOpacity(0.06),
                                ],
                              ),
                              border: Border.all(
                                color: AppTheme.primaryOrange
                                    .withOpacity(0.12),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryOrange
                                      .withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.sports_cricket,
                              size: 48.sp,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 36.h),

                  // ── 1. Title ──
                  _animatedItem(
                    1,
                    Text(
                      'Login to ScorePartner',
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

                  SizedBox(height: 12.h),

                  // ── 2. Subtitle ──
                  _animatedItem(
                    2,
                    Text(
                      'Track your cricket journey, join matches,\nand connect with players',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── 3. Continue with Mobile (Primary CTA) ──
                  _animatedItem(
                    3,
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: AnimatedBuilder(
                        animation: _shimmerAnimation,
                        builder: (context, child) {
                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16.r),
                              gradient: LinearGradient(
                                begin: Alignment(
                                    -1.0 + _shimmerAnimation.value, -0.5),
                                end: Alignment(
                                    _shimmerAnimation.value, 0.5),
                                colors: [
                                  AppTheme.primaryOrange,
                                  const Color(0xFFFF6B35),
                                  const Color(0xFFFFAB76),
                                  const Color(0xFFFF6B35),
                                  AppTheme.primaryOrange,
                                ],
                                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
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
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16.r),
                            onTap: () {
                              Navigator.push(
                                context,
                                _createRoute(const PhoneAuthScreen()),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 18.h),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6.w),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius:
                                          BorderRadius.circular(8.r),
                                    ),
                                    child: Icon(Icons.phone_android_rounded,
                                        size: 20.sp, color: Colors.white),
                                  ),
                                  SizedBox(width: 14.w),
                                  Text(
                                    'Continue with Mobile',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Icon(Icons.arrow_forward_rounded,
                                      size: 18.sp, color: Colors.white70),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // ── 4. Continue with Email ──
                  _animatedItem(
                    4,
                    _buildOutlineButton(
                      icon: Icons.email_rounded,
                      label: 'Continue with Email',
                      iconColor: AppTheme.primaryOrange,
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          _createRoute(const EmailAuthScreen()),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 12.h),

                  // ── 5. Continue with Google ──
                  _animatedItem(
                    5,
                    _buildOutlineButton(
                      icon: null,
                      googleLogo: true,
                      label: 'Continue with Google',
                      iconColor: const Color(0xFF4285F4),
                      isDark: isDark,
                      onTap: () => _signInWithGoogle(context),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── 6. Terms ──
                  _animatedItem(
                    6,
                    Padding(
                      padding: EdgeInsets.only(bottom: 24.h),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark
                                ? Colors.grey[600]
                                : Colors.grey[400],
                            height: 1.6,
                          ),
                          children: [
                            const TextSpan(
                                text:
                                    'By continuing, you agree to our '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: AppTheme.primaryOrange
                                    .withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const TextSpan(text: '\nand '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: AppTheme.primaryOrange
                                    .withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Outline button with glassmorphism ──
  Widget _buildOutlineButton({
    IconData? icon,
    bool googleLogo = false,
    required String label,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              color: (isDark ? Colors.white : Colors.white)
                  .withOpacity(isDark ? 0.06 : 0.65),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black)
                    .withOpacity(0.08),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (googleLogo)
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'G',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: iconColor,
                      ),
                    ),
                  )
                else if (icon != null)
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child:
                        Icon(icon, size: 20.sp, color: iconColor),
                  ),
                SizedBox(width: 14.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Smooth page route transition ──
  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        final fadeTween = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut));
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  void _signInWithGoogle(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.signInWithGoogle();

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        if (authProvider.isFirstTimeUser) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (_) => const UserOnboardingScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (_) => const MainNavigation()),
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
}

// ── Floating Orbs Painter ──
class _OrbsPainter extends CustomPainter {
  final double animValue;
  final Color color;
  final bool isDark;

  _OrbsPainter({
    required this.animValue,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final orbs = [
      _Orb(0.2, 0.12, 0.7, 0.5, 45, isDark ? 0.05 : 0.07),
      _Orb(0.85, 0.3, 0.4, 0.6, 35, isDark ? 0.04 : 0.06),
      _Orb(0.5, 0.65, 0.3, 0.8, 30, isDark ? 0.04 : 0.05),
      _Orb(0.12, 0.5, 0.9, 0.4, 20, isDark ? 0.03 : 0.04),
      _Orb(0.75, 0.82, 1.1, 0.7, 16, isDark ? 0.05 : 0.07),
      _Orb(0.4, 0.9, 0.6, 0.5, 12, isDark ? 0.04 : 0.06),
    ];

    for (final orb in orbs) {
      final x = size.width * orb.baseX +
          math.sin(animValue * orb.speedX) * 25;
      final y = size.height * orb.baseY +
          math.cos(animValue * orb.speedY) * 20;
      paint.color = color.withOpacity(orb.opacity);
      canvas.drawCircle(Offset(x, y), orb.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbsPainter old) =>
      old.animValue != animValue;
}

class _Orb {
  final double baseX, baseY, speedX, speedY, radius, opacity;
  const _Orb(this.baseX, this.baseY, this.speedX, this.speedY, this.radius,
      this.opacity);
}
