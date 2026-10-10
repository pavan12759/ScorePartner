import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageUtils {
  static final Map<String, Uint8List> _base64Cache = {};

  /// Returns an ImageProvider that globally caches decoded base64 bytes
  static ImageProvider getProfileImageProvider(String url, {String fallbackAsset = 'assets/images/default_avatar.png'}) {
    if (url.isEmpty) {
      return AssetImage(fallbackAsset);
    }
    
    if (url.trim().startsWith('data:')) {
      try {
        final base64Str = url.split(',').last.trim();
        if (_base64Cache.containsKey(base64Str)) {
          return MemoryImage(_base64Cache[base64Str]!);
        }
        final bytes = base64Decode(base64Str);
        _base64Cache[base64Str] = bytes;
        return MemoryImage(bytes);
      } catch (_) {
        return AssetImage(fallbackAsset);
      }
    }
    return NetworkImage(url);
  }

  /// Builds an Image widget that globally caches decoded base64 bytes
  static Widget buildProfileImage(String url, double size, {IconData fallbackIcon = Icons.person, Color fallbackColor = Colors.grey}) {
    if (url.isEmpty) {
      return Icon(fallbackIcon, size: size * 0.5, color: fallbackColor);
    }
    
    if (url.trim().startsWith('data:')) {
      try {
        final base64Str = url.split(',').last.trim();
        if (!_base64Cache.containsKey(base64Str)) {
          _base64Cache[base64Str] = base64Decode(base64Str);
        }
        return Image.memory(
          _base64Cache[base64Str]!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } catch (_) {
        return Icon(fallbackIcon, size: size * 0.5, color: fallbackColor);
      }
    }
    
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: size * 0.5, color: fallbackColor),
    );
  }
}
