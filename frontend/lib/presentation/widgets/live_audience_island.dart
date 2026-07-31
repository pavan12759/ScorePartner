import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Cricbuzz-style floating live audience indicator.
///
/// **Collapsed**: Compact dark pill — green pulsing LIVE dot + eye icon + count.
/// **Expanded**: Clean dark card with team names, viewer stats in a row.
class LiveAudienceIsland extends StatefulWidget {
  final String matchId;
  final String? tournamentName;
  final String ground;
  final String team1Name;
  final String team2Name;
  final int liveViewers;
  final int totalViews;
  final int peakViewers;
  final bool isLive;
  final VoidCallback? onLongPress;

  const LiveAudienceIsland({
    super.key,
    required this.matchId,
    this.tournamentName,
    required this.ground,
    required this.team1Name,
    required this.team2Name,
    required this.liveViewers,
    required this.totalViews,
    required this.peakViewers,
    required this.isLive,
    this.onLongPress,
  });

  @override
  State<LiveAudienceIsland> createState() => _LiveAudienceIslandState();
}

class _LiveAudienceIslandState extends State<LiveAudienceIsland>
    with TickerProviderStateMixin {
  // ── Animations ───────────────────────────────────────────────────
  late AnimationController _expandCtrl;
  late Animation<double> _expandT;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseT;

  late AnimationController _countUpCtrl;
  late Animation<double> _countUpT;

  bool _isExpanded = false;
  Timer? _autoHideTimer;

  // ── Cricbuzz colors ──────────────────────────────────────────────
  static const _bgDark = Color(0xFF1B1B2F);
  static const _bgCard = Colors.white;
  static const _liveGreen = Color(0xFF00C853);
  static const _accentTeal = Color(0xFF26A69A);
  static const _statOrange = Color(0xFFE64A19); // Darker orange for white bg
  static const _statYellow = Color(0xFFF57F17); // Darker yellow for white bg

  // ── Dimensions ───────────────────────────────────────────────────
  static const double _collapsedH = 60.0;
  static const double _collapsedW = 60.0;
  static const double _expandedH = 92.0;
  static const double _expandedW = 260.0;

  @override
  void initState() {
    super.initState();

    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandT = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _pulseT = Tween<double>(begin: 0, end: 1).animate(_pulseCtrl);

    _countUpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _countUpT = CurvedAnimation(parent: _countUpCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    _pulseCtrl.dispose();
    _countUpCtrl.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _expandCtrl.forward();
      _countUpCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isExpanded) _startAutoHide();
      });
    } else {
      _expandCtrl.reverse();
      _autoHideTimer?.cancel();
    }
    HapticFeedback.lightImpact();
  }

  void _startAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (_isExpanded && mounted) {
        setState(() => _isExpanded = false);
        _expandCtrl.reverse();
      }
    });
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleExpanded,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _expandT,
        builder: (ctx, _) {
          final t = _expandT.value;
          final w = _collapsedW + t * (_expandedW - _collapsedW);
          final h = _collapsedH + t * (_expandedH - _collapsedH);
          final radius = 12.0 + (1 - t) * 6.0; // 18 collapsed → 12 expanded

          return SizedBox(
            width: w,
            height: h,
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.lerp(Colors.white, _bgCard, t),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.08 + 0.04 * t),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: t > 0.5
                    ? _buildExpandedContent()
                    : _buildCollapsedContent(),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Collapsed: Circle with White Background ───────────────────────────────

  Widget _buildCollapsedContent() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Eye icon
        Icon(
          Icons.remove_red_eye_rounded,
          color: Colors.black87,
          size: 22.sp,
        ),

        // Viewer count badge (bottom‑right)
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            constraints: BoxConstraints(minWidth: 22.w),
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8A50), Color(0xFFFF6B00)],
              ),
              borderRadius: BorderRadius.circular(10.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B00).withOpacity(0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _fmt(widget.liveViewers),
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.sp,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Pulsing live dot (top‑left)
        if (widget.isLive)
          Positioned(
            left: 4,
            top: 4,
            child: AnimatedBuilder(
              animation: _pulseT,
              builder: (ctx, _) {
                final pulseVal = (0.5 + 0.5 * math.sin(_pulseT.value * 2 * math.pi)).clamp(0.3, 1.0);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ring
                    Container(
                      width: 12 + 4 * pulseVal,
                      height: 12 + 4 * pulseVal,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _liveGreen.withOpacity(0.3 * pulseVal),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Inner dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _liveGreen,
                        boxShadow: [
                          BoxShadow(
                            color: _liveGreen.withOpacity(0.5 * pulseVal),
                            blurRadius: 6 * pulseVal,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Expanded card ────────────────────────────────────────────────

  Widget _buildExpandedContent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: OverflowBox(
        minHeight: 0,
        maxHeight: double.infinity,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: LIVE dot + team names
            _buildHeaderRow(),
            SizedBox(height: 8.h),
            // Row 2: Stats
            _buildStatsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        // LIVE badge
        if (widget.isLive) ...[
          AnimatedBuilder(
            animation: _pulseT,
            builder: (ctx, _) {
              final pv = (0.5 + 0.5 * math.sin(_pulseT.value * 2 * math.pi))
                  .clamp(0.4, 1.0);
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: _liveGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(
                    color: _liveGreen.withOpacity(0.3 + 0.2 * pv),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _liveGreen,
                        boxShadow: [
                          BoxShadow(
                            color: _liveGreen.withOpacity(0.5 * pv),
                            blurRadius: 3 * pv,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: _liveGreen,
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(width: 8.w),
        ],
        // Team names
        Expanded(
          child: Text(
            '${widget.team1Name} vs ${widget.team2Name}',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCell(
            icon: Icons.visibility_rounded,
            value: _fmt((widget.liveViewers * _countUpT.value).round()),
            label: 'Watching',
            color: _liveGreen,
          ),
        ),
        _buildDivider(),
        Expanded(
          child: _buildStatCell(
            icon: Icons.play_circle_outline_rounded,
            value: _fmt((widget.totalViews * _countUpT.value).round()),
            label: 'Views',
            color: _statOrange,
          ),
        ),
        _buildDivider(),
        Expanded(
          child: _buildStatCell(
            icon: Icons.bolt_rounded,
            value: _fmt((widget.peakViewers * _countUpT.value).round()),
            label: 'Peak',
            color: _statYellow,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCell({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11.sp, color: color),
            SizedBox(width: 3.w),
            Text(
              value,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        Text(
          label,
          style: TextStyle(
            color: Colors.black54,
            fontSize: 8.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 22,
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      color: Colors.black12,
    );
  }
}
