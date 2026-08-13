import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import 'animated_otp_digit.dart';

class PremiumOtpInput extends StatefulWidget {
  final ValueChanged<String> onCompleted;
  final bool hasError;
  final bool isSuccess;
  final bool isVerifying;
  final String? errorMessage;

  const PremiumOtpInput({
    Key? key,
    required this.onCompleted,
    this.hasError = false,
    this.isSuccess = false,
    this.isVerifying = false,
    this.errorMessage,
  }) : super(key: key);

  @override
  State<PremiumOtpInput> createState() => _PremiumOtpInputState();
}

class _PremiumOtpInputState extends State<PremiumOtpInput>
    with TickerProviderStateMixin {
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _morphController;
  late Animation<double> _morphAnimation;

  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(6, (index) => FocusNode());
    _controllers = List.generate(6, (index) => TextEditingController());

    for (int i = 0; i < 6; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          setState(() {
            _focusedIndex = i;
          });
        }
      });
    }

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 0), weight: 1),
    ]).animate(_shakeController);

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeInOutBack,
    );

    // Request focus on the first digit initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(PremiumOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _shakeController.forward(from: 0.0);
    }
    
    if (widget.isSuccess && !oldWidget.isSuccess) {
      _morphController.forward();
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    _shakeController.dispose();
    _morphController.dispose();
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      // Check for paste (more than 1 character)
      if (value.length > 1) {
        _handlePaste(value);
        return;
      }
      
      // Regular input
      _controllers[index].text = value;
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _checkCompletion();
      }
    } else {
      // Deletion is handled by RawKeyboardListener backspace in AnimatedOtpDigit
      // but we still want to trigger UI update
      setState(() {});
    }
  }

  void _handleBackspace(int index) {
    if (index > 0) {
      _controllers[index - 1].text = '';
      _focusNodes[index - 1].requestFocus();
      setState(() {});
    }
  }

  void _handlePaste(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '').split('');
    int i = 0;
    while (i < digits.length && i < 6) {
      _controllers[i].text = digits[i];
      i++;
    }
    
    if (i > 0) {
      if (i < 6) {
        _focusNodes[i].requestFocus();
      } else {
        _focusNodes[5].unfocus();
        _checkCompletion();
      }
    }
    setState(() {});
  }

  void _checkCompletion() {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6) {
      widget.onCompleted(otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child,
            );
          },
          child: AnimatedBuilder(
            animation: _morphAnimation,
            builder: (context, child) {
              // Morph logic: move them to center and fade out, show checkmark
              final progress = _morphAnimation.value;
              final opacity = 1.0 - progress.clamp(0.0, 1.0);
              
              if (progress > 0.8) {
                // Success State Fully morphed
                return _buildSuccessCheckmark();
              }
              
              return Opacity(
                opacity: opacity,
                child: AutofillGroup(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      // Calculate dynamic offset to pull boxes to center
                      final centerOffset = (2.5 - index) * 30.0 * progress;
                      
                      return Transform.translate(
                        offset: Offset(centerOffset, 0),
                        child: AnimatedOtpDigit(
                          focusNode: _focusNodes[index],
                          controller: _controllers[index],
                          hasError: widget.hasError,
                          isFocused: _focusedIndex == index,
                          onChanged: (value) => _onDigitChanged(index, value),
                          onBackspace: () => _handleBackspace(index),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Error Message
        if (widget.hasError && widget.errorMessage != null) ...[
          SizedBox(height: 16.h),
          FadeTransition(
            opacity: _shakeController,
            child: Text(
              widget.errorMessage!,
              style: TextStyle(
                color: Colors.red,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        
        // Verifying Loading State
        if (widget.isVerifying) ...[
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 16.h,
                width: 16.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryOrange,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Verifying...',
                style: TextStyle(
                  color: AppTheme.darkGrey,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSuccessCheckmark() {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _morphController,
        curve: const Interval(0.8, 1.0, curve: Curves.easeOutBack),
      ),
      child: Container(
        width: 60.w,
        height: 60.w,
        decoration: const BoxDecoration(
          color: AppTheme.primaryOrange,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}
