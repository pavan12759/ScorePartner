import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

class AppException implements Exception {
  final String title;
  final String message;

  AppException(this.title, this.message);

  factory AppException.from(dynamic exception) {
    if (exception is TimeoutException) {
      return AppException(
        'Request Timeout',
        'This is taking longer than expected. Please check your connection and try again.',
      );
    }
    if (exception is SocketException) {
      return AppException(
        'Network Error',
        'Couldn\'t connect to the server. Check your internet connection and try again.',
      );
    }
    if (exception is FirebaseException) {
      if (exception.code == 'permission-denied') {
        return AppException(
          'Access Denied',
          'You don\'t have permission to perform this action.',
        );
      }
      if (exception.code == 'unavailable') {
         return AppException(
          'Service Unavailable',
          'The service is currently unavailable. Please try again later.',
        );
      }
      return AppException('Server Error', exception.message ?? 'An unknown server error occurred.');
    }
    if (exception is PlatformException) {
      return AppException('System Error', exception.message ?? 'An unknown system error occurred.');
    }
    
    // For standard exceptions with generic messages
    final String errorStr = exception.toString();
    if (errorStr.contains('Exception:')) {
      return AppException('Error', errorStr.replaceAll('Exception:', '').trim());
    }
    
    return AppException('Something went wrong', 'We couldn\'t complete your request right now.');
  }

  @override
  String toString() => '$title: $message';
}
