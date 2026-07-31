import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/match_model.dart';

/// Decision enum for Super Over tie resolution
enum SuperOverTieDecision { playAnother, declareTie }

/// Premium modal dialog shown when a Super Over ends in a tie.
/// Admin must choose to play another Super Over or declare the match as tied.
class SuperOverTieDialog extends StatefulWidget {
  final MatchModel match;

  const SuperOverTieDialog({super.key, required this.match});

  @override
  State<SuperOverTieDialog> createState() => _SuperOverTieDialogState();
}

class _SuperOverTieDialogState extends State<SuperOverTieDialog>
    with SingleTickerProviderStateMixin {
  SuperOverTieDecision? _hoveredOption;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Theme colors matching the app's existing dark theme
  static const Color _dialogBg = Color(0xFF1C1C22);
  static const Color _cardBg = Color(0xFF252530);
  static const Color _cardBgHover = Color(0xFF2A2A38);
  static const Color _amberGlow = Color(0xFFFFB300);
  static const Color _orangeAccent = Color(0xFFFF6B00);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0B0BA);
  static const Color _textMuted = Color(0xFF6E6E78);
  static const Color _borderSubtle = Color(0xFF3A3A45);
  static const Color _tieBadgeBg = Color(0xFF2D1F00);

  @override
  Widget build(BuildContext context) {
    final soNumber = widget.match.superOverNumber;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 32.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 420.w),
        decoration: BoxDecoration(
          color: _dialogBg,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: _amberGlow.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _amberGlow.withOpacity(0.08),
              blurRadius: 40,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header ───
            _buildHeader(soNumber),

            // ─── Content ───
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
              child: Column(
                children: [
                  // Score summary
                  _buildScoreSummary(),

                  SizedBox(height: 20.h),

                  // Message
                  Text(
                    'The Super Over has also ended in a tie.\nChoose how this match should continue according to your tournament rules.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13.sp,
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // ─── Option Cards ───
                  _buildPlayAnotherCard(),
                  SizedBox(height: 12.h),
                  _buildDeclareTieCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int soNumber) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 20.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _tieBadgeBg,
            _dialogBg,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          // Pulsing cricket icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _amberGlow.withOpacity(0.2 * _pulseAnimation.value),
                      Colors.transparent,
                    ],
                    radius: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '🏏',
                    style: TextStyle(fontSize: 32.sp),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 12.h),
          // Title
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [_amberGlow, _orangeAccent],
            ).createShader(bounds),
            child: Text(
              'Super Over Tied!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (soNumber > 1) ...[
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: _amberGlow.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                'Super Over #$soNumber',
                style: TextStyle(
                  color: _amberGlow,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreSummary() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _borderSubtle, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTeamMini(widget.match.team1Name, widget.match.team1Score),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: _amberGlow.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                'TIE',
                style: TextStyle(
                  color: _amberGlow,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          _buildTeamMini(widget.match.team2Name, widget.match.team2Score),
        ],
      ),
    );
  }

  Widget _buildTeamMini(String name, TeamScore score) {
    return Column(
      children: [
        Text(
          name.length > 12 ? '${name.substring(0, 12)}...' : name,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          '${score.runs}/${score.wickets}',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '(${score.oversDisplay} ov)',
          style: TextStyle(
            color: _textMuted,
            fontSize: 10.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayAnotherCard() {
    final isHovered = _hoveredOption == SuperOverTieDecision.playAnother;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredOption = SuperOverTieDecision.playAnother),
      onExit: (_) => setState(() => _hoveredOption = null),
      child: GestureDetector(
        onTap: () => Navigator.pop(context, SuperOverTieDecision.playAnother),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isHovered ? _cardBgHover : _cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: _orangeAccent.withOpacity(isHovered ? 0.7 : 0.4),
              width: isHovered ? 2.0 : 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _orangeAccent.withOpacity(isHovered ? 0.12 : 0.06),
                _cardBg,
              ],
            ),
            boxShadow: isHovered
                ? [BoxShadow(color: _orangeAccent.withOpacity(0.15), blurRadius: 16)]
                : [],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: _orangeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text('🔁', style: TextStyle(fontSize: 22.sp)),
                ),
              ),
              SizedBox(width: 14.w),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Play Another Super Over',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Start another Super Over with the same teams. Continue until a winner is decided.',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 11.sp,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: _orangeAccent.withOpacity(0.6),
                size: 16.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeclareTieCard() {
    final isHovered = _hoveredOption == SuperOverTieDecision.declareTie;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredOption = SuperOverTieDecision.declareTie),
      onExit: (_) => setState(() => _hoveredOption = null),
      child: GestureDetector(
        onTap: () => Navigator.pop(context, SuperOverTieDecision.declareTie),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isHovered ? _cardBgHover : _cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: _borderSubtle.withOpacity(isHovered ? 0.9 : 0.6),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: _textMuted.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text('🤝', style: TextStyle(fontSize: 22.sp)),
                ),
              ),
              SizedBox(width: 14.w),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Declare Match as Tie',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'End the match officially as a Tie. All statistics will be saved.',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 11.sp,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: _textMuted.withOpacity(0.4),
                size: 16.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
