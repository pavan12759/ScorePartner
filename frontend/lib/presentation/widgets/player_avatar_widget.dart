import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_utils.dart';
import '../../data/models/user_model.dart';
import '../../data/services/firebase_data_service.dart';
import '../screens/profile/player_profile_screen.dart';

/// Reusable Player Avatar Widget across the entire ScorePartner app.
/// Features:
/// - Displays actual player profile photo (base64 or remote URL)
/// - Asynchronous fallback lookup via `playerId` with global in-memory caching
/// - Dynamic sporty gradient fallback with player initials
/// - Tap to view full `PlayerProfileScreen`
/// - Optional badge overlay (Captain C, Vice Captain VC, Wicket Keeper WK, etc.)
class PlayerAvatarWidget extends StatefulWidget {
  final String? profileImageUrl;
  final String? playerId;
  final String playerName;
  final double size;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final Border? border;
  final bool enableProfileView;
  final VoidCallback? onTap;
  final Widget? badge;
  final Alignment badgeAlignment;
  final Object? heroTag;

  const PlayerAvatarWidget({
    super.key,
    this.profileImageUrl,
    this.playerId,
    required this.playerName,
    this.size = 40,
    this.shape = BoxShape.circle,
    this.borderRadius,
    this.border,
    this.enableProfileView = true,
    this.onTap,
    this.badge,
    this.badgeAlignment = Alignment.bottomRight,
    this.heroTag,
  });

  /// Global in-memory cache to prevent repeated network/Firestore lookups
  static final Map<String, String> _photoCache = {};
  static final Map<String, UserModel> _userCache = {};
  static final Set<String> _inFlightFetches = {};

  /// Preload a batch of player photos into memory
  static Future<void> prefetch(Iterable<String> playerIds) async {
    final toFetch = playerIds.where((id) =>
        id.isNotEmpty &&
        !_photoCache.containsKey(id) &&
        !_inFlightFetches.contains(id)).toList();

    if (toFetch.isEmpty) return;

    for (final id in toFetch) {
      _inFlightFetches.add(id);
    }

    await Future.wait(toFetch.map((id) async {
      try {
        final user = await FirebaseDataService.instance.findUserByAnyId(id);
        if (user != null) {
          _userCache[id] = user;
          _photoCache[id] = user.profileImageUrl;
        } else {
          _photoCache[id] = '';
        }
      } catch (_) {
        _photoCache[id] = '';
      } finally {
        _inFlightFetches.remove(id);
      }
    }));
  }

  /// Manually seed or update photo cache
  static void seedCache(String id, String photoUrl, [UserModel? user]) {
    if (id.isEmpty) return;
    _photoCache[id] = photoUrl;
    if (user != null) {
      _userCache[id] = user;
    }
  }

  /// Get cached photo URL if available
  static String? getCachedPhoto(String? id) {
    if (id == null || id.isEmpty) return null;
    return _photoCache[id];
  }

  @override
  State<PlayerAvatarWidget> createState() => _PlayerAvatarWidgetState();
}

class _PlayerAvatarWidgetState extends State<PlayerAvatarWidget> {
  String? _resolvedUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolvePhoto();
  }

  @override
  void didUpdateWidget(covariant PlayerAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profileImageUrl != oldWidget.profileImageUrl ||
        widget.playerId != oldWidget.playerId ||
        widget.playerName != oldWidget.playerName) {
      _resolvePhoto();
    }
  }

  void _resolvePhoto() {
    // 1. Direct photo URL provided
    if (widget.profileImageUrl != null && widget.profileImageUrl!.trim().isNotEmpty) {
      setState(() {
        _resolvedUrl = widget.profileImageUrl!.trim();
      });
      return;
    }

    final pid = widget.playerId?.trim() ?? '';
    final name = widget.playerName.trim();

    // Check in-memory cache with pid or name
    if (pid.isNotEmpty && PlayerAvatarWidget._photoCache.containsKey(pid)) {
      setState(() {
        _resolvedUrl = PlayerAvatarWidget._photoCache[pid];
      });
      return;
    }
    if (name.isNotEmpty && PlayerAvatarWidget._photoCache.containsKey(name)) {
      setState(() {
        _resolvedUrl = PlayerAvatarWidget._photoCache[name];
      });
      return;
    }

    // Trigger async lookup
    final lookupKey = pid.isNotEmpty ? pid : name;
    if (lookupKey.isNotEmpty) {
      _fetchUserPhoto(lookupKey);
    }
  }

  Future<void> _fetchUserPhoto(String lookupKey) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      UserModel? user = await FirebaseDataService.instance.findUserByAnyId(lookupKey);

      // Fallback search by playerName if lookupKey was an unresolvable ID
      final name = widget.playerName.trim();
      if (user == null && name.isNotEmpty && name != lookupKey) {
        user = await FirebaseDataService.instance.findUserByAnyId(name);
      }

      if (!mounted) return;

      if (user != null) {
        final resolvedUser = user;
        final photoUrl = resolvedUser.profileImageUrl;

        PlayerAvatarWidget._userCache[lookupKey] = resolvedUser;
        if (resolvedUser.uid.isNotEmpty) {
          PlayerAvatarWidget._userCache[resolvedUser.uid] = resolvedUser;
          PlayerAvatarWidget._photoCache[resolvedUser.uid] = photoUrl;
        }
        if (widget.playerId?.isNotEmpty == true) {
          PlayerAvatarWidget._photoCache[widget.playerId!] = photoUrl;
          PlayerAvatarWidget._userCache[widget.playerId!] = resolvedUser;
        }
        if (name.isNotEmpty) {
          PlayerAvatarWidget._photoCache[name] = photoUrl;
          PlayerAvatarWidget._userCache[name] = resolvedUser;
        }
        PlayerAvatarWidget._photoCache[lookupKey] = photoUrl;

        setState(() {
          _resolvedUrl = photoUrl;
          _isLoading = false;
        });
      } else {
        PlayerAvatarWidget._photoCache[lookupKey] = '';
        if (widget.playerId?.isNotEmpty == true) PlayerAvatarWidget._photoCache[widget.playerId!] = '';
        if (name.isNotEmpty) PlayerAvatarWidget._photoCache[name] = '';
        setState(() {
          _resolvedUrl = '';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleTap() async {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }

    if (!widget.enableProfileView) return;

    final pid = widget.playerId?.trim() ?? '';
    final name = widget.playerName.trim();
    final lookupKey = pid.isNotEmpty ? pid : name;
    if (lookupKey.isEmpty) return;

    // Check if user is cached
    UserModel? user = PlayerAvatarWidget._userCache[lookupKey] ??
        (pid.isNotEmpty ? PlayerAvatarWidget._userCache[pid] : null) ??
        (name.isNotEmpty ? PlayerAvatarWidget._userCache[name] : null);

    if (user != null) {
      _openProfile(user);
      return;
    }

    // Fetch user if not cached
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      ),
    );

    try {
      user = await FirebaseDataService.instance.findUserByAnyId(lookupKey);
      if (user == null && name.isNotEmpty && name != lookupKey) {
        user = await FirebaseDataService.instance.findUserByAnyId(name);
      }
      if (!mounted) return;
      Navigator.pop(context); // dismiss progress

      if (user != null) {
        PlayerAvatarWidget._userCache[lookupKey] = user;
        if (pid.isNotEmpty) PlayerAvatarWidget._userCache[pid] = user;
        if (name.isNotEmpty) PlayerAvatarWidget._userCache[name] = user;
        _openProfile(user);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player profile not found or unregistered')),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load player profile')),
        );
      }
    }
  }

  void _openProfile(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfileScreen(player: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _resolvedUrl != null && _resolvedUrl!.isNotEmpty;
    final borderRadius = widget.shape == BoxShape.circle
        ? BorderRadius.circular(widget.size / 2)
        : (widget.borderRadius ?? BorderRadius.circular(widget.size * 0.22));

    Widget imageContent;

    if (hasPhoto) {
      ImageProvider provider;
      if (_resolvedUrl!.trim().startsWith('data:')) {
        try {
          final base64Str = _resolvedUrl!.split(',').last.trim();
          final bytes = base64Decode(base64Str);
          provider = MemoryImage(bytes);
        } catch (_) {
          provider = ImageUtils.getProfileImageProvider(_resolvedUrl!);
        }
      } else {
        provider = NetworkImage(_resolvedUrl!);
      }

      imageContent = ClipRRect(
        borderRadius: borderRadius,
        child: Image(
          image: provider,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(borderRadius),
        ),
      );
    } else {
      imageContent = _buildFallbackAvatar(borderRadius);
    }

    Widget mainAvatar = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.circle ? null : borderRadius,
        border: widget.border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: imageContent,
    );

    if (widget.heroTag != null) {
      mainAvatar = Hero(tag: widget.heroTag!, child: mainAvatar);
    }

    if (widget.badge != null) {
      mainAvatar = Stack(
        clipBehavior: Clip.none,
        alignment: widget.badgeAlignment,
        children: [
          mainAvatar,
          widget.badge!,
        ],
      );
    }

    if (widget.onTap != null || (widget.enableProfileView && (widget.playerId?.isNotEmpty ?? false))) {
      return GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: mainAvatar,
      );
    }

    return mainAvatar;
  }

  Widget _buildFallbackAvatar(BorderRadius borderRadius) {
    final isDark = ThemeHelper.of(context).isDark;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.circle ? null : borderRadius,
        color: isDark ? const Color(0xFF2C3240) : const Color(0xFFE2E8F0),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: widget.size * 0.65,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
    );
  }
}
