import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';

class AnimatedOtpDigit extends StatefulWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  final bool isFocused;

  const AnimatedOtpDigit({
    Key? key,
    required this.focusNode,
    required this.controller,
    required this.hasError,
    required this.onChanged,
    required this.onBackspace,
    this.isFocused = false,
  }) : super(key: key);

  @override
  State<AnimatedOtpDigit> createState() => _AnimatedOtpDigitState();
}

class _AnimatedOtpDigitState extends State<AnimatedOtpDigit> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50.w,
      height: 65.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2), // ScorePartner light orange tint card
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: widget.hasError
              ? Colors.red
              : widget.isFocused
                  ? AppTheme.primaryOrange
                  : Colors.grey.shade300,
          width: widget.isFocused || widget.hasError ? 2 : 1,
        ),
        boxShadow: widget.isFocused
            ? [
                BoxShadow(
                  color: AppTheme.primaryOrange.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: RawKeyboardListener(
        focusNode: FocusNode(), // Dummy focus node to capture key events before text field
        onKey: (event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.backspace) {
              if (widget.controller.text.isEmpty) {
                widget.onBackspace();
              }
            }
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The actual invisible text field
            TextField(
              focusNode: widget.focusNode,
              controller: widget.controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              style: const TextStyle(color: Colors.transparent),
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                counterText: '',
                fillColor: Colors.transparent,
              ),
              onChanged: widget.onChanged,
              enableInteractiveSelection: false,
            ),
            
            // The animated text display
            IgnorePointer(
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, child) {
                  final text = widget.controller.text;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final isEntering = child.key == ValueKey(text);
                          
                          // Use a curved animation for smoother flipping
                          final curve = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                          );
                          
                          double angle;
                          if (isEntering) {
                             // Entering: rotates from -90 degrees (-pi/2) to 0
                             angle = (1.0 - curve.value) * (-1.5708);
                          } else {
                             // Leaving: rotates from 0 to 90 degrees (pi/2)
                             angle = (1.0 - curve.value) * (1.5708);
                          }
                          
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002) // 3D perspective
                              ..rotateX(angle),
                            child: Opacity(
                              opacity: animation.value.clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                    child: Text(
                      text.isNotEmpty ? text : '',
                      key: ValueKey<String>(text),
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepBlack,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
