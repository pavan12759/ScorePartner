import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_theme.dart';

class TossSelectionDialog extends StatefulWidget {
  final String team1Name;
  final String team2Name;

  const TossSelectionDialog({
    super.key,
    required this.team1Name,
    required this.team2Name,
  });

  @override
  State<TossSelectionDialog> createState() => _TossSelectionDialogState();
}

class _TossSelectionDialogState extends State<TossSelectionDialog> {
  // 0 for team1, 1 for team2
  int _selectedTeamIndex = -1;
  // 'bat' or 'field'
  String _selectedDecision = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Container(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Who Won the Toss?',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: _buildSelectableCard(
                    title: widget.team1Name,
                    isSelected: _selectedTeamIndex == 0,
                    onTap: () => setState(() => _selectedTeamIndex = 0),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildSelectableCard(
                    title: widget.team2Name,
                    isSelected: _selectedTeamIndex == 1,
                    onTap: () => setState(() => _selectedTeamIndex = 1),
                  ),
                ),
              ],
            ),
            
            if (_selectedTeamIndex != -1) ...[
              SizedBox(height: 24.h),
              Text(
                '${_selectedTeamIndex == 0 ? widget.team1Name : widget.team2Name} elected to:',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: _buildSelectableCard(
                      title: 'BAT',
                      icon: Icons.sports_cricket,
                      isSelected: _selectedDecision == 'bat',
                      onTap: () => setState(() => _selectedDecision = 'bat'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildSelectableCard(
                      title: 'BOWL',
                      icon: Icons.sports_baseball, // Using baseball icon as closest 'ball' representation or just distinct icon
                      isSelected: _selectedDecision == 'field',
                      onTap: () => setState(() => _selectedDecision = 'field'),
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: (_selectedTeamIndex != -1 && _selectedDecision.isNotEmpty)
                  ? () {
                      Navigator.pop(context, {
                        'winnerIndex': _selectedTeamIndex, // 0 or 1
                        'decision': _selectedDecision, // 'bat' or 'field'
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: const Text('Start Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectableCard({
    required String title,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryOrange.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
            width: 2.w,
          ),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryOrange : Colors.grey[600],
                size: 28.sp,
              ),
              SizedBox(height: 8.h),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryOrange : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14.sp,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
