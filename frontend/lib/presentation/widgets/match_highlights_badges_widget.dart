import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scorepatner/core/theme/app_theme.dart';
import 'package:scorepatner/data/models/match_model.dart';
import 'package:scorepatner/presentation/widgets/highlight_badge_widgets.dart';

class MatchHighlightsBadgesWidget extends StatelessWidget {
  final MatchModel match;

  const MatchHighlightsBadgesWidget({
    super.key,
    required this.match,
  });

  ImageProvider _getHighlightImageProvider(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final uri = Uri.parse(imageUrl);
        if (uri.data != null) {
          return MemoryImage(uri.data!.contentAsBytes());
        }
      } catch (e) {
        debugPrint('Error parsing highlight base64 image: $e');
      }
    }
    return NetworkImage(imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (match.highlights.isEmpty) return SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stars_rounded, color: Colors.amber, size: 22.sp),
                SizedBox(width: 8.w),
                Text(
                  'MATCH BADGES',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            SizedBox(
              height: 190.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: match.highlights.length,
                itemBuilder: (context, index) {
                  final highlight = match.highlights[index];
                  return _buildHighlightCard(context, highlight);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  BadgeType _parseBadgeType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'tournament_win':
      case 'win': return BadgeType.win;
      case 'century': return BadgeType.century;
      case 'halfcentury':
      case 'half_century':
      case 'fifty': return BadgeType.fifty;
      case 'fivewickets':
      case 'five_wickets':
      case 'wicket': return BadgeType.wicket;
      case 'manofmatch':
      case 'man_of_match':
      case 'mvp': return BadgeType.mvp;
      default: return BadgeType.fifty;
    }
  }

  Widget _buildHighlightCard(BuildContext context, MatchHighlight highlight) {
    return GestureDetector(
      onTap: () => _showFullHighlightDialog(context, highlight),
      child: Padding(
        padding: EdgeInsets.only(right: 12.0.w),
        child: Container(
          width: 140.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 400.w,
                height: 500.h,
                child: IgnorePointer(
                  child: HighlightBadgeCard(
                    type: _parseBadgeType(highlight.type),
                    title: highlight.title,
                    description: highlight.description,
                    matchName: match.matchName,
                    ground: match.ground ?? '',
                    date: DateFormat('dd MMM yyyy').format(match.scheduledDate),
                    playerName: highlight.playerName ?? '',
                    playerPhoto: highlight.imageUrl.isNotEmpty ? highlight.imageUrl : null,
                    team1Name: match.team1Name,
                    team2Name: match.team2Name,
                    team1Score: '${match.team1Score.runs}/${match.team1Score.wickets} (${match.team1Score.oversDisplay} ov)',
                    team2Score: '${match.team2Score.runs}/${match.team2Score.wickets} (${match.team2Score.oversDisplay} ov)',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullHighlightDialog(BuildContext context, MatchHighlight highlight) {
    final screenshotController = ScreenshotController();
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close Button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 28.sp),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            
            // Image Card
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24.r),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 400.w,
                    height: 500.h,
                    child: Screenshot(
                      controller: screenshotController,
                      child: HighlightBadgeCard(
                        type: _parseBadgeType(highlight.type),
                        title: highlight.title,
                        description: highlight.description,
                        matchName: match.matchName,
                        ground: match.ground ?? '',
                        date: DateFormat('dd MMM yyyy').format(match.scheduledDate),
                        playerName: highlight.playerName ?? '',
                        playerPhoto: highlight.imageUrl.isNotEmpty ? highlight.imageUrl : null,
                        team1Name: match.team1Name,
                        team2Name: match.team2Name,
                        team1Score: '${match.team1Score.runs}/${match.team1Score.wickets} (${match.team1Score.oversDisplay} ov)',
                        team2Score: '${match.team2Score.runs}/${match.team2Score.wickets} (${match.team2Score.oversDisplay} ov)',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 20.h),
            
            // Share Button
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // Capture the exact widget currently rendered on screen
                  final imageBytes = await screenshotController.capture(
                    delay: const Duration(milliseconds: 10),
                    pixelRatio: 3.0,
                  );

                  if (imageBytes != null) {
                    await Share.shareXFiles(
                      [
                        XFile.fromData(
                          imageBytes,
                          mimeType: 'image/png',
                          name: 'highlight_${highlight.id}.png',
                        )
                      ],
                      text: 'Check out my match highlight on ScorePartner! 🏏🏆\n#Cricket #ScorePartner',
                      subject: highlight.title,
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to share: $e')),
                  );
                }
              },
              icon: Icon(Icons.share),
              label: const Text('SHARE MOMENT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
