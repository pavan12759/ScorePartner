import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'firebase_data_service.dart';

enum PlayerSearchMethod {
  sppId,
  mobileNumber,
  unknown,
}

class PlayerSearchResult {
  final bool isSuccess;
  final UserModel? player;
  final String? errorMessage;
  final PlayerSearchMethod searchMethod;
  final String normalizedQuery;

  const PlayerSearchResult._({
    required this.isSuccess,
    this.player,
    this.errorMessage,
    required this.searchMethod,
    required this.normalizedQuery,
  });

  factory PlayerSearchResult.success({
    required UserModel player,
    required PlayerSearchMethod searchMethod,
    required String normalizedQuery,
  }) {
    return PlayerSearchResult._(
      isSuccess: true,
      player: player,
      searchMethod: searchMethod,
      normalizedQuery: normalizedQuery,
    );
  }

  factory PlayerSearchResult.failure({
    required String errorMessage,
    PlayerSearchMethod searchMethod = PlayerSearchMethod.unknown,
    String normalizedQuery = '',
  }) {
    return PlayerSearchResult._(
      isSuccess: false,
      errorMessage: errorMessage,
      searchMethod: searchMethod,
      normalizedQuery: normalizedQuery,
    );
  }
}

/// Shared player search service for looking up registered players
/// by SPP ID (SPP + 8 digits) or Indian mobile number (+91 / without +91 / formatted)
class PlayerSearchService {
  static PlayerSearchService? _instance;
  static PlayerSearchService get instance => _instance ??= PlayerSearchService._();
  PlayerSearchService._();

  /// Normalize Indian mobile numbers:
  /// - Strips spaces, hyphens, parens, plus sign
  /// - Strips leading 0 (11 digits), 91 (12 digits), 091 (13 digits)
  /// - Returns 10-digit number if valid, null otherwise
  static String? normalizeIndianPhone(String input) {
    if (input.trim().isEmpty) return null;
    String digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    } else if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('091') && digits.length == 13) {
      digits = digits.substring(3);
    }

    if (digits.length == 10) {
      return digits;
    }

    return null;
  }

  /// Mask phone number for privacy: e.g. "+91 ****** 1136"
  static String maskPhoneNumber(String phone) {
    if (phone.isEmpty) return '';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '******';
    final last4 = digits.substring(digits.length - 4);
    return '+91 ****** $last4';
  }

  /// Automatically detect which search method to use based on the input string
  static PlayerSearchMethod detectSearchMethod(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return PlayerSearchMethod.unknown;

    // Check if input starts with SPP (case-insensitive)
    if (trimmed.toUpperCase().startsWith('SPP')) {
      return PlayerSearchMethod.sppId;
    }

    // Check if input is potentially a phone number (contains digits, no letters)
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(trimmed);
    if (!hasLetters) {
      final normalized = normalizeIndianPhone(trimmed);
      if (normalized != null) {
        return PlayerSearchMethod.mobileNumber;
      }
    }

    return PlayerSearchMethod.unknown;
  }

  /// Search for a registered player by SPP ID or mobile number
  /// Returns existing player profile without creating duplicates or exposing complete phone
  Future<PlayerSearchResult> searchPlayer(String rawInput) async {
    final query = rawInput.trim();
    if (query.isEmpty) {
      return PlayerSearchResult.failure(
        errorMessage: 'Please enter an SPP ID or mobile number',
      );
    }

    final method = detectSearchMethod(query);

    switch (method) {
      case PlayerSearchMethod.sppId:
        return _searchBySppId(query);

      case PlayerSearchMethod.mobileNumber:
        final normalized = normalizeIndianPhone(query)!;
        return _searchByMobileNumber(normalized);

      case PlayerSearchMethod.unknown:
        final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(query);
        if (hasLetters) {
          return PlayerSearchResult.failure(
            errorMessage: 'Invalid SPP ID format. Example: SPP12345678',
            searchMethod: PlayerSearchMethod.unknown,
            normalizedQuery: query,
          );
        } else {
          return PlayerSearchResult.failure(
            errorMessage: 'Invalid mobile number. Please enter a 10-digit mobile number',
            searchMethod: PlayerSearchMethod.unknown,
            normalizedQuery: query,
          );
        }
    }
  }

  Future<PlayerSearchResult> _searchBySppId(String sppId) async {
    final normalizedId = sppId.toUpperCase();
    debugPrint('🔍 [PlayerSearchService] Searching by SPP ID: $normalizedId');

    try {
      // 1. Try direct Firestore lookup first (instantaneous on mobile)
      final user = await FirebaseDataService.instance.getUserBySppId(normalizedId);
      if (user != null) {
        return PlayerSearchResult.success(
          player: user,
          searchMethod: PlayerSearchMethod.sppId,
          normalizedQuery: normalizedId,
        );
      }

      // 2. Try Node.js backend API with a short timeout
      try {
        final res = await ApiService.instance
            .lookupUserBySppId(normalizedId)
            .timeout(const Duration(seconds: 2));
        if (res.containsKey('user') && res['user'] != null) {
          final userMap = Map<String, dynamic>.from(res['user'] as Map);
          if (userMap['phoneNumber'] != null && userMap['phoneNumber'].toString().isNotEmpty) {
            userMap['phoneNumber'] = maskPhoneNumber(userMap['phoneNumber'].toString());
          }
          final apiUser = UserModel.fromMap(userMap);
          return PlayerSearchResult.success(
            player: apiUser,
            searchMethod: PlayerSearchMethod.sppId,
            normalizedQuery: normalizedId,
          );
        }
      } catch (apiError) {
        debugPrint('ℹ️ [PlayerSearchService] Backend API lookup error/skip: $apiError');
      }

      return PlayerSearchResult.failure(
        errorMessage: 'No registered player found',
        searchMethod: PlayerSearchMethod.sppId,
        normalizedQuery: normalizedId,
      );
    } catch (e) {
      debugPrint('❌ [PlayerSearchService] Search by SPP ID exception: $e');
      return PlayerSearchResult.failure(
        errorMessage: 'Error searching player: $e',
        searchMethod: PlayerSearchMethod.sppId,
        normalizedQuery: normalizedId,
      );
    }
  }

  Future<PlayerSearchResult> _searchByMobileNumber(String tenDigits) async {
    debugPrint('🔍 [PlayerSearchService] Searching by mobile number: $tenDigits');

    try {
      // 1. Try direct Firestore lookup first (instantaneous on mobile)
      final user = await FirebaseDataService.instance.getUserByPhone(tenDigits);
      if (user != null) {
        return PlayerSearchResult.success(
          player: user,
          searchMethod: PlayerSearchMethod.mobileNumber,
          normalizedQuery: tenDigits,
        );
      }

      // 2. Try Node.js backend API with a short timeout
      try {
        final res = await ApiService.instance
            .lookupUserByPhone(tenDigits)
            .timeout(const Duration(seconds: 2));
        if (res.containsKey('user') && res['user'] != null) {
          final userMap = Map<String, dynamic>.from(res['user'] as Map);
          if (userMap['phoneNumber'] != null && userMap['phoneNumber'].toString().isNotEmpty) {
            userMap['phoneNumber'] = maskPhoneNumber(userMap['phoneNumber'].toString());
          }
          final apiUser = UserModel.fromMap(userMap);
          return PlayerSearchResult.success(
            player: apiUser,
            searchMethod: PlayerSearchMethod.mobileNumber,
            normalizedQuery: tenDigits,
          );
        }
      } catch (apiError) {
        debugPrint('ℹ️ [PlayerSearchService] Backend API phone lookup error/skip: $apiError');
      }

      return PlayerSearchResult.failure(
        errorMessage: 'No registered player found',
        searchMethod: PlayerSearchMethod.mobileNumber,
        normalizedQuery: tenDigits,
      );
    } catch (e) {
      debugPrint('❌ [PlayerSearchService] Search by mobile number exception: $e');
      return PlayerSearchResult.failure(
        errorMessage: 'Error searching player: $e',
        searchMethod: PlayerSearchMethod.mobileNumber,
        normalizedQuery: tenDigits,
      );
    }
  }
}
