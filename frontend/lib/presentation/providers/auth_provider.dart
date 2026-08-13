import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/api_service.dart';
import '../../data/services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  final ApiService _apiService = ApiService.instance;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  bool _isAuthInitialized = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isAuthInitialized => _isAuthInitialized;
  
  /// Check if user needs to complete onboarding
  bool get isFirstTimeUser => _user != null && _user!.isProfileComplete == false;

  AuthProvider() {
    _authService.initialize(); // Initialize listener
    _authService.authStateChanges.listen((UserModel? user) async {
      _user = user;
      // Sync Firebase ID token with API service
      await _syncAuthToken();
      
      // Setup Push Notifications for user
      if (user != null) {
        await NotificationService().setupForUser(user.uid);
      } else {
        await NotificationService().clearUser();
      }
      
      // Mark auth as initialized after first check
      if (!_isAuthInitialized) {
        _isAuthInitialized = true;
      }
      
      notifyListeners();
    });
  }

  /// Sync Firebase auth token with API service for backend calls
  Future<void> _syncAuthToken() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        final token = await firebaseUser.getIdToken();
        await _apiService.setAuthToken(token);
        debugPrint('🔑 API token synced with Firebase');
      } catch (e) {
        debugPrint('⚠️ Failed to sync API token: $e');
      }
    } else {
      await _apiService.setAuthToken(null);
    }
  }

  /// Sign in with phone number (OTP flow)
  Future<void> signInWithPhone(
    String phoneNumber,
    Function(String) onVerificationId,
  ) async {
    _setLoading(true);
    try {
      await _authService.signInWithPhone(phoneNumber);
      // Pass phone number as verification ID for OTP flow
      onVerificationId(phoneNumber); 
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
    _setLoading(false);
  }

  /// Sign in with email (OTP flow)
  Future<void> signInWithEmail(
    String email,
    Function(String) onVerificationId,
  ) async {
    _setLoading(true);
    try {
      await _authService.signInWithEmail(email);
      onVerificationId(email); 
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
    _setLoading(false);
  }

  /// Verify Email OTP code
  Future<void> verifyEmailOtp(String email, String otp) async {
    _setLoading(true);
    try {
      UserModel userModel = await _authService.verifyEmailOtp(email, otp);
      _user = userModel;
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
    _setLoading(false);
  }

  /// Verify OTP code
  Future<void> verifyOtp(String verificationId, String otp) async {
    _setLoading(true);
    try {
      // verificationId is actually the phoneNumber in our new flow
      UserModel userModel = await _authService.verifyOtp(verificationId, otp);
      _user = userModel;
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
    _setLoading(false);
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    try {
      UserModel userModel = await _authService.signInWithGoogle();
      _user = userModel;
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
    _setLoading(false);
  }

  /// Sign in with Email and Password
  Future<void> signInWithEmailPassword(String email, String password, {bool isSignUp = false}) async {
    _setLoading(true);
    try {
      UserModel userModel = await _authService.signInWithEmailPassword(email, password, isSignUp: isSignUp);
      _user = userModel;
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
    _setLoading(false);
  }

  // Additional auth methods can be added here in the future

  Future<UserModel?> getUserDetails() async {
    if (_user != null) {
      return _user;
    }
    return null;
  }
  
  /// Refreshes the currently authenticated user's data from Firebase
  Future<void> refreshUser() async {
    if (_user == null) return;
    _setLoading(true);
    try {
       final freshUser = await _authService.getUserById(_user!.uid);
       if (freshUser != null) {
         _user = freshUser;
       }
    } catch (e) {
      debugPrint('Error refreshing user: $e');
    }
    _setLoading(false);
  }

  Future<void> updateUserProfile(UserModel user) async {
    _setLoading(true);
    try {
      await _authService.updateUserProfile(user);
      _user = user.copyWith(isProfileComplete: true);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
    _setLoading(false);
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await NotificationService().clearUser(); // Clear token before sign out
      await _authService.signOut();
      _user = null;
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
    _setLoading(false);
  }

  void clearError() {
    _clearError();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    if (error.startsWith('Exception: ')) {
      _errorMessage = error.replaceFirst('Exception: ', '');
    } else {
      _errorMessage = error;
    }
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
