import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_theme.dart';

/// Reusable team logo widget that shows:
/// - Uploaded logo image (from URL) if available
/// - In-memory image bytes (during creation, before upload)
/// - Auto-generated initials avatar with gradient as fallback
class TeamLogoWidget extends StatelessWidget {
  final String? logoUrl;
  final Uint8List? imageBytes;
  final String teamName;
  final double size;
  final VoidCallback? onTap;

  const TeamLogoWidget({
    super.key,
    this.logoUrl,
    this.imageBytes,
    required this.teamName,
    this.size = 60,
    this.onTap,
  });

  /// Generate a consistent gradient from team name
  static List<Color> _gradientForName(String name) {
    final hash = name.hashCode.abs();
    final gradients = [
      [AppTheme.primaryOrange, AppTheme.deepOrange],
      [const Color(0xFF6C63FF), const Color(0xFF9D4EDD)],
      [const Color(0xFF00B4D8), const Color(0xFF0077B6)],
      [const Color(0xFF2EC4B6), const Color(0xFF20A39E)],
      [const Color(0xFFE63946), const Color(0xFFF4845F)],
      [const Color(0xFFF72585), const Color(0xFFB5179E)],
      [const Color(0xFF06D6A0), const Color(0xFF118AB2)],
      [const Color(0xFFFFB703), const Color(0xFFFB8500)],
    ];
    return gradients[hash % gradients.length].cast<Color>();
  }

  /// Get initials from team name (max 2 chars)
  static String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (imageBytes != null) {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.25),
          image: DecorationImage(
            image: MemoryImage(imageBytes!),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
      );
    } else if (logoUrl != null && logoUrl!.isNotEmpty) {
      // Determine image provider: base64 data URL or network URL
      ImageProvider imageProvider;
      if (logoUrl!.trim().startsWith('data:')) {
        try {
          final base64Str = logoUrl!.split(',').last;
          final bytes = base64Decode(base64Str);
          imageProvider = MemoryImage(bytes);
        } catch (_) {
          return _buildInitialsAvatar();
        }
      } else {
        imageProvider = NetworkImage(logoUrl!);
      }

      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.25),
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
            onError: (_, __) {},
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
      );
    } else {
      avatar = _buildInitialsAvatar();
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            avatar,
            Positioned(
              bottom: 0.h,
              right: 0.w,
              child: Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.w),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: size * 0.2,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return avatar;
  }

  Widget _buildInitialsAvatar() {
    final gradient = _gradientForName(teamName);
    final initials = _getInitials(teamName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.4),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
