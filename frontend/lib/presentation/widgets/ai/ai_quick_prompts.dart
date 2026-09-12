import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';

/// Quick prompt suggestion chips for AI chat
class AIQuickPrompts extends StatelessWidget {
  final void Function(String prompt) onPromptTap;

  const AIQuickPrompts({super.key, required this.onPromptTap});

  static const List<_QuickPrompt> _prompts = [
    _QuickPrompt(icon: '🏏', text: 'Show today\'s matches', color: Color(0xFFE8F5E9)),
    _QuickPrompt(icon: '👤', text: 'Find a player', color: Color(0xFFE3F2FD)),
    _QuickPrompt(icon: '🏆', text: 'Show my tournaments', color: Color(0xFFFFF3E0)),
    _QuickPrompt(icon: '📰', text: 'Latest cricket news', color: Color(0xFFFCE4EC)),
    _QuickPrompt(icon: '🌍', text: 'What\'s new from ICC?', color: Color(0xFFE0F7FA)),
    _QuickPrompt(icon: '📊', text: 'Show top players', color: Color(0xFFF3E5F5)),
    _QuickPrompt(icon: '📖', text: 'Explain DLS rule', color: Color(0xFFE8EAF6)),
    _QuickPrompt(icon: '⚙️', text: 'How do I create a tournament?', color: Color(0xFFFFF8E1)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Welcome section
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            children: [
              SizedBox(height: 24.h),
              // AI Icon
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryOrange,
                      AppTheme.primaryOrange.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryOrange.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.sports_cricket,
                  color: Colors.white,
                  size: 32.sp,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'ScorePartner AI',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Your cricket & ScorePartner assistant',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey.shade500,
                ),
              ),
              SizedBox(height: 28.h),
              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Text(
                      'Try asking',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                ],
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),

        // Prompt chips
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: _prompts.map((prompt) {
              return InkWell(
                onTap: () => onPromptTap(prompt.text),
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.06)
                        : prompt.color,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white12
                          : prompt.color.withOpacity(0.0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(prompt.icon, style: TextStyle(fontSize: 16.sp)),
                      SizedBox(width: 6.w),
                      Text(
                        prompt.text,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }
}

class _QuickPrompt {
  final String icon;
  final String text;
  final Color color;
  const _QuickPrompt({required this.icon, required this.text, required this.color});
}
