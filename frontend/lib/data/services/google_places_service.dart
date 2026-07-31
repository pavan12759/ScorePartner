import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A place prediction from Google Places Autocomplete
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}

/// Place details with coordinates
class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  const PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });
}

/// Service for Google Places API calls
class GooglePlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  // TODO: Replace with your actual API key
  static const String _apiKey = 'AIzaSyBtTSPe_sYeFGhxyLkyE3QH8Bc8ykYV37o';

  final Dio _dio;

  GooglePlacesService._() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static final GooglePlacesService instance = GooglePlacesService._();

  /// Search for places using Google Places Autocomplete API
  /// Biased towards India and prioritizes cricket grounds/stadiums
  Future<List<PlacePrediction>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];
    if (_apiKey.isEmpty) {
      debugPrint('⚠️ Google Places API key not configured');
      return [];
    }

    try {
      final queryParams = {
        'input': query,
        'key': _apiKey,
        'components': 'country:in', // Bias to India
        'types': 'establishment|geocode', // Places and addresses
        'language': 'en',
      };

      final uri = Uri.parse('$_baseUrl/autocomplete/json').replace(queryParameters: queryParams);
      String requestUrl = uri.toString();
      
      if (kIsWeb) {
        // Use our local Node.js backend proxy to completely bypass CORS 
        requestUrl = 'http://localhost:5000/api/proxy?url=${Uri.encodeComponent(requestUrl)}';
      }

      final response = await _dio.get(requestUrl);

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = json.decode(data);
          } catch (_) {}
        }
        if (data is Map && data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions.map((p) {
            final structured = p['structured_formatting'] ?? {};
            return PlacePrediction(
              placeId: p['place_id'] ?? '',
              description: p['description'] ?? '',
              mainText: structured['main_text'] ?? p['description'] ?? '',
              secondaryText: structured['secondary_text'] ?? '',
            );
          }).toList();
        } else if (data is Map && data['status'] != 'OK') {
          debugPrint('⚠️ Google Places API Error: ${data['error_message']} (Status: ${data['status']})');
        }
      }
    } catch (e) {
      debugPrint('Places API error: $e');
    }
    return [];
  }

  /// Get place details (lat/lng) by placeId
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    if (_apiKey.isEmpty) return null;

    try {
      final queryParams = {
        'place_id': placeId,
        'key': _apiKey,
        'fields': 'name,formatted_address,geometry',
      };

      final uri = Uri.parse('$_baseUrl/details/json').replace(queryParameters: queryParams);
      String requestUrl = uri.toString();
      
      if (kIsWeb) {
        // Use our local Node.js backend proxy to completely bypass CORS
        requestUrl = 'http://localhost:5000/api/proxy?url=${Uri.encodeComponent(requestUrl)}';
      }

      final response = await _dio.get(requestUrl);

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = json.decode(data);
          } catch (_) {}
        }
        if (data is Map && data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          return PlaceDetails(
            placeId: placeId,
            name: result['name'] ?? '',
            formattedAddress: result['formatted_address'] ?? '',
            latitude: (location['lat'] as num).toDouble(),
            longitude: (location['lng'] as num).toDouble(),
          );
        }
      }
    } catch (e) {
      debugPrint('Place Details API error: $e');
    }
    return null;
  }
}
