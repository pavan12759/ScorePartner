import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery or camera
  Future<XFile?> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      return image;
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      return null;
    }
  }

  /// Upload profile image — returns base64 data URL (no Firebase Storage needed)
  Future<String?> uploadProfileImage(String userId, XFile imageFile) async {
    try {
      final Uint8List rawBytes = await imageFile.readAsBytes();
      debugPrint('📸 Profile image raw size: ${rawBytes.length} bytes');

      // Resize to 200x200 to keep Firestore doc small
      Uint8List finalBytes = rawBytes;
      try {
        final codec = await ui.instantiateImageCodec(
          rawBytes,
          targetWidth: 200,
          targetHeight: 200,
        );
        final frame = await codec.getNextFrame();
        final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          finalBytes = byteData.buffer.asUint8List();
          debugPrint('📸 Resized to 200x200: ${finalBytes.length} bytes');
        }
      } catch (e) {
        debugPrint('⚠️ Resize failed, using original: $e');
      }

      final base64Image = base64Encode(finalBytes);
      final dataUrl = 'data:image/png;base64,$base64Image';
      debugPrint('✅ Profile image data URL ready (${dataUrl.length} chars)');
      return dataUrl;
    } catch (e) {
      debugPrint('❌ Error processing profile image: $e');
      throw Exception('Upload failed: $e');
    }
  }
}
