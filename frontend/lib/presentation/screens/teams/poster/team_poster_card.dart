import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../data/models/team_model.dart';
import '../../../../core/utils/image_utils.dart';
import 'team_poster_theme.dart';

/// The Visual Poster Widget for a Cricket Team Squad
/// Displays team branding, captaincy, stats, and every player's photo & role.
class TeamPosterCard extends StatelessWidget {
  final TeamModel team;
  final TeamPosterTheme theme;
  final Map<String, String> resolvedPhotos;
  final String tagline;
  final bool showStats;
  final bool showQrCode;
  final bool showRoles;
  final bool showCaptainsBadge;
  final bool themeLogo;
  final int columns;
  final double cardWidth;

  const TeamPosterCard({
    super.key,
    required this.team,
    required this.theme,
    required this.resolvedPhotos,
    this.tagline = 'OFFICIAL SQUAD • 2026',
    this.showStats = false,
    this.showQrCode = true,
    this.showRoles = true,
    this.showCaptainsBadge = true,
    this.themeLogo = true,
    this.columns = 0,
    this.cardWidth = 460,
  });

  int get _effectiveColumns {
    if (columns > 0) return columns;
    final count = team.players.length;
    if (count <= 6) return 2;
    if (count > 15) return 4;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final cols = _effectiveColumns;
    final totalPlayers = team.players.length;

    return Container(
      width: cardWidth,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.backgroundGradient,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: theme.cardBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: theme.accentColor.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Atmospheric Lighting (Spotlights & Flares)
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.accentColor.withOpacity(0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.secondaryAccent.withOpacity(0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: cardWidth / 4,
            child: Container(
              width: 260,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.accentColor.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Poster Content
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Badge
                _buildTopBrandHeader(),
                SizedBox(height: 12.h),

                // Team Crest & Identity
                _buildTeamIdentity(),
                SizedBox(height: 10.h),

                // Leadership Badges (Captain & Vice Captain)
                if (showCaptainsBadge &&
                    (team.captainName.isNotEmpty || team.viceCaptainName.isNotEmpty)) ...[
                  _buildLeadershipStrip(),
                  SizedBox(height: 10.h),
                ],

                // Team Performance Stats (Played, Won, Win %)
                if (showStats) ...[
                  _buildStatsBanner(),
                  SizedBox(height: 12.h),
                ],

                // Squad Section Divider
                _buildSquadDivider(totalPlayers),
                SizedBox(height: 12.h),

                // Squad Players Grid
                if (totalPlayers == 0)
                  _buildEmptySquadState()
                else
                  _buildPlayersGrid(cols),

                SizedBox(height: 16.h),

                // Poster Footer & Watermark
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Top Brand Header Bar with Sporty Badge
  Widget _buildTopBrandHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7.r),
                border: Border.all(
                  color: themeLogo
                      ? theme.accentColor.withOpacity(0.55)
                      : Colors.white24,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (themeLogo ? theme.accentColor : Colors.black).withOpacity(0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: themeLogo
                    ? Container(
                        padding: EdgeInsets.all(2.5.w),
                        decoration: BoxDecoration(
                          color: theme.cardBackground,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.accentColor.withOpacity(0.25),
                              theme.cardBackground,
                            ],
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/app_icon_foreground.png',
                          fit: BoxFit.contain,
                          color: theme.accentColor,
                        ),
                      )
                    : Image.asset(
                        'assets/images/app_icon.png',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'ScorePartner',
              style: GoogleFonts.outfit(
                color: themeLogo ? theme.accentColor : Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        if (team.spTId.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: theme.cardBackground,
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(color: theme.cardBorder),
            ),
            child: Text(
              team.spTId,
              style: GoogleFonts.robotoMono(
                color: theme.goldAccent,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
      ],
    );
  }

  /// Team Logo, Name, and Tagline
  Widget _buildTeamIdentity() {
    return Column(
      children: [
        // Logo with Glowing Aura
        Container(
          width: 72.w,
          height: 72.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.accentColor,
                theme.secondaryAccent,
                theme.goldAccent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.accentColor.withOpacity(0.45),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: EdgeInsets.all(2.5.w),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0D1117),
            ),
            clipBehavior: Clip.antiAlias,
            child: team.logoUrl.isNotEmpty
                ? ImageUtils.buildProfileImage(
                    team.logoUrl,
                    68.w,
                    fallbackIcon: Icons.shield,
                    fallbackColor: theme.accentColor,
                  )
                : Center(
                    child: Text(
                      _getInitials(team.name),
                      style: GoogleFonts.bebasNeue(
                        color: theme.accentColor,
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
        SizedBox(height: 8.h),

        // Team Name
        Text(
          team.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.bebasNeue(
            color: theme.textPrimary,
            fontSize: 28.sp,
            letterSpacing: 2.2,
            height: 1.05,
            shadows: [
              Shadow(
                color: theme.accentColor.withOpacity(0.7),
                blurRadius: 10,
              ),
            ],
          ),
        ),

        // Tagline / Subtitle
        if (tagline.isNotEmpty) ...[
          SizedBox(height: 3.h),
          Text(
            tagline.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: theme.textSecondary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ],
      ],
    );
  }

  /// Leadership Row (Captain & Vice Captain)
  Widget _buildLeadershipStrip() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8.w,
      runSpacing: 6.h,
      children: [
        if (team.captainName.isNotEmpty)
          _buildRoleChip(
            label: 'CAPTAIN',
            name: team.captainName,
            icon: Icons.star,
            color: theme.goldAccent,
          ),
        if (team.viceCaptainName.isNotEmpty)
          _buildRoleChip(
            label: 'VICE-CAPTAIN',
            name: team.viceCaptainName,
            icon: Icons.shield_outlined,
            color: const Color(0xFF38BDF8),
          ),
      ],
    );
  }

  Widget _buildRoleChip({
    required String label,
    required String name,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12.sp),
          SizedBox(width: 4.w),
          Text(
            '$label: ',
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            name,
            style: GoogleFonts.outfit(
              color: theme.textPrimary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Team Performance Stats Banner
  Widget _buildStatsBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: theme.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: theme.cardBorder.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('MATCHES', '${team.matchesPlayed}', theme.textPrimary),
          _buildStatDivider(),
          _buildStatItem('WON', '${team.matchesWon}', const Color(0xFF4ADE80)),
          _buildStatDivider(),
          _buildStatItem('LOST', '${team.matchesLost}', const Color(0xFFF87171)),
          if (team.matchesPlayed > 0) ...[
            _buildStatDivider(),
            _buildStatItem('WIN %', '${team.winPercentage.toStringAsFixed(0)}%', theme.accentColor),
          ],
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 20.h,
      width: 1,
      color: theme.cardBorder.withOpacity(0.3),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.bebasNeue(
            color: color,
            fontSize: 16.sp,
            letterSpacing: 1,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: theme.textSecondary.withOpacity(0.8),
            fontSize: 8.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  /// Squad Divider with Accent Bats
  Widget _buildSquadDivider(int count) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  theme.cardBorder,
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 8.w),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: theme.bannerColor,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: theme.accentColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_rounded, color: theme.accentColor, size: 12.sp),
              SizedBox(width: 5.w),
              Text(
                'SQUAD MEMBERS ($count)',
                style: GoogleFonts.outfit(
                  color: theme.textPrimary,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.cardBorder,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Empty Squad Warning State
  Widget _buildEmptySquadState() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.person_add_alt_1_outlined, color: theme.accentColor, size: 36.sp),
          SizedBox(height: 8.h),
          Text(
            'No players added to this squad yet',
            style: GoogleFonts.outfit(color: theme.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4.h),
          Text(
            'Add players to your team to showcase them on this poster.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }

  /// Dynamic Grid of Players
  Widget _buildPlayersGrid(int cols) {
    final players = team.players;
    final rowCount = (players.length / cols).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        final startIndex = rowIndex * cols;
        final endIndex = (startIndex + cols > players.length) ? players.length : startIndex + cols;
        final rowPlayers = players.sublist(startIndex, endIndex);

        return Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(cols, (colIndex) {
              if (colIndex < rowPlayers.length) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: _buildPlayerCard(rowPlayers[colIndex], cols),
                  ),
                );
              } else {
                return const Expanded(child: SizedBox.shrink());
              }
            }),
          ),
        );
      }),
    );
  }

  /// Single Player Card inside Squad Grid
  Widget _buildPlayerCard(TeamPlayer player, int cols) {
    // Resolve photo URL from lookup cache or direct model
    final photoUrl = resolvedPhotos[player.userId] ??
        resolvedPhotos[player.name] ??
        player.profileImageUrl;

    final isCaptain = player.isCaptain || (team.captainId.isNotEmpty && (team.captainId == player.userId || team.captainName == player.name));
    final isViceCaptain = player.isViceCaptain || (team.viceCaptainId.isNotEmpty && (team.viceCaptainId == player.userId || team.viceCaptainName == player.name));

    // Dynamic sizing based on column density
    final avatarSize = cols == 2 ? 56.w : (cols == 4 ? 40.w : 48.w);

    // Role colors
    Color roleColor;
    final roleLower = player.role.toLowerCase();
    if (roleLower.contains('bat')) {
      roleColor = const Color(0xFFFF5722);
    } else if (roleLower.contains('bowl')) {
      roleColor = const Color(0xFF10B981);
    } else if (roleLower.contains('all')) {
      roleColor = const Color(0xFFA855F7);
    } else if (roleLower.contains('keep') || roleLower.contains('wk')) {
      roleColor = const Color(0xFF06B6D4);
    } else {
      roleColor = theme.accentColor;
    }

    // Border color based on leadership
    final borderColor = isCaptain
        ? theme.goldAccent
        : (isViceCaptain ? const Color(0xFF38BDF8) : roleColor.withOpacity(0.5));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: theme.cardBackground.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isCaptain
              ? theme.goldAccent.withOpacity(0.7)
              : (isViceCaptain ? const Color(0xFF38BDF8).withOpacity(0.6) : theme.cardBorder.withOpacity(0.35)),
          width: isCaptain || isViceCaptain ? 1.5 : 1,
        ),
        boxShadow: [
          if (isCaptain)
            BoxShadow(
              color: theme.goldAccent.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player Avatar with Role/Leadership Badge
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withOpacity(0.25),
                      blurRadius: 6,
                    ),
                  ],
                ),
                padding: EdgeInsets.all(1.5.w),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF0F172A),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: photoUrl.isNotEmpty
                      ? _buildPlayerPhotoWidget(photoUrl, avatarSize, player.name)
                      : _buildFallbackAvatar(player.name, avatarSize, roleColor),
                ),
              ),

              // Captain / Vice-Captain Badge Overlay
              if (isCaptain)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: theme.goldAccent,
                      borderRadius: BorderRadius.circular(6.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      'C',
                      style: GoogleFonts.bebasNeue(
                        color: Colors.black,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else if (isViceCaptain)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8),
                      borderRadius: BorderRadius.circular(6.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      'VC',
                      style: GoogleFonts.bebasNeue(
                        color: Colors.black,
                        fontSize: 8.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: 5.h),

          // Player Name
          Text(
            player.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: isCaptain ? theme.goldAccent : theme.textPrimary,
              fontSize: cols == 4 ? 9.5.sp : (cols == 2 ? 12.sp : 10.5.sp),
              fontWeight: FontWeight.w700,
            ),
          ),

          // Role Badge
          if (showRoles && player.role.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(color: roleColor.withOpacity(0.3), width: 0.8),
              ),
              child: Text(
                player.role.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: roleColor,
                  fontSize: cols == 4 ? 6.5.sp : 7.5.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Photo widget handling both Base64 and Network URLs
  Widget _buildPlayerPhotoWidget(String url, double size, String name) {
    if (url.trim().startsWith('data:')) {
      try {
        final base64Str = url.split(',').last.trim();
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } catch (_) {
        return _buildFallbackAvatar(name, size, theme.accentColor);
      }
    }

    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, _) => _buildFallbackAvatar(name, size, theme.accentColor),
    );
  }

  /// Gradient initials fallback avatar
  Widget _buildFallbackAvatar(String name, double size, Color accent) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.4),
            theme.cardBackground,
          ],
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(name),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: (size * 0.38).sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Poster Footer & App Verification
  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: theme.bannerColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: theme.cardBorder.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Info
          Expanded(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5.r),
                  child: themeLogo
                      ? Container(
                          width: 20.w,
                          height: 20.w,
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                            color: theme.cardBackground,
                            border: Border.all(color: theme.accentColor.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                          child: Image.asset(
                            'assets/images/app_icon_foreground.png',
                            fit: BoxFit.contain,
                            color: theme.accentColor,
                          ),
                        )
                      : Image.asset(
                          'assets/images/app_icon.png',
                          width: 20.w,
                          height: 20.w,
                          fit: BoxFit.cover,
                        ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ScorePartner',
                        style: GoogleFonts.outfit(
                          color: themeLogo ? theme.accentColor : theme.textPrimary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Official Squad Roster',
                        style: GoogleFonts.outfit(
                          color: theme.textSecondary.withOpacity(0.7),
                          fontSize: 8.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Optional QR Code for Team Join
          if (showQrCode && team.spTId.isNotEmpty)
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: QrImageView(
                    data: team.spTId,
                    version: QrVersions.auto,
                    size: 34.w,
                    padding: EdgeInsets.zero,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                  ),
                ),
                SizedBox(width: 6.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SCAN TO JOIN',
                      style: GoogleFonts.outfit(
                        color: theme.goldAccent,
                        fontSize: 7.5.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      team.spTId,
                      style: GoogleFonts.robotoMono(
                        color: theme.textSecondary,
                        fontSize: 7.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _getInitials(String text) {
    if (text.trim().isEmpty) return 'SP';
    final parts = text.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
