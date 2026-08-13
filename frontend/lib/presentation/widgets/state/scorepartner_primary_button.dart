import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';

enum ButtonState { normal, loading, success, error, disabled }

class ScorePartnerPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonState state;
  final String? successText;
  final String? errorText;
  final double? width;
  final double height;
  final Color? backgroundColor;

  const ScorePartnerPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.state = ButtonState.normal,
    this.successText,
    this.errorText,
    this.width,
    this.height = 48.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Color getBackgroundColor() {
      if (state == ButtonState.disabled) return Colors.grey.shade400;
      if (state == ButtonState.success) return Colors.green;
      if (state == ButtonState.error) return Colors.red;
      return backgroundColor ?? AppTheme.primaryOrange;
    }

    Widget getChild() {
      switch (state) {
        case ButtonState.loading:
          return SizedBox(
            height: 20.h,
            width: 20.h,
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          );
        case ButtonState.success:
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8.w),
              Text(
                successText ?? 'Success',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        case ButtonState.error:
          return Text(
            errorText ?? 'Failed - Try Again',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          );
        case ButtonState.disabled:
        case ButtonState.normal:
        default:
          return Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          );
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width ?? double.infinity,
      height: height.h,
      child: ElevatedButton(
        onPressed: (state == ButtonState.loading || state == ButtonState.disabled || state == ButtonState.success)
            ? null
            : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: getBackgroundColor(),
          disabledBackgroundColor: getBackgroundColor(), // Keep color same but disable clicks
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: state == ButtonState.normal ? 2 : 0,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: getChild(),
        ),
      ),
    );
  }
}
