import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

/// Firebase Authentication Service
/// Supports: Phone OTP, Email Link, Google Sign-In
class AuthService {
  // Singleton
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  final StreamController<UserModel?> _authStateController =
      StreamController<UserModel?>.broadcast();

  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // Store verification ID for phone auth
  String? _verificationId;
  int? _resendToken;

  /// Initialize the service and listen to auth state changes
  void initialize() {
    debugPrint('🔐 Firebase Auth Service initialized');
    
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        // Load user profile from Firestore
        _currentUser = await _loadUserProfile(firebaseUser);
        _authStateController.add(_currentUser);
      } else {
        _currentUser = null;
        _authStateController.add(null);
      }
    });
  }

  /// Load user profile from Firestore, create if doesn't exist
  /// Falls back to local profile if Firestore is unavailable
  Future<UserModel> _loadUserProfile(User firebaseUser) async {
    try {
      final docRef = _firestore.collection('users').doc(firebaseUser.uid);
      final doc = await docRef.get();
      
      if (doc.exists) {
        return UserModel.fromMap({...doc.data()!, 'uid': firebaseUser.uid});
      } else {
        // Create new user profile
        final newUser = _createLocalUserProfile(firebaseUser);
        
        try {
          await docRef.set(newUser.toMap());
          debugPrint('✅ User profile saved to Firestore');
        } catch (e) {
          debugPrint('⚠️ Could not save profile to Firestore (offline): $e');
          // Continue with local profile even if save fails
        }
        return newUser;
      }
    } catch (e) {
      debugPrint('⚠️ Firestore unavailable, using local profile: $e');
      // Fallback: Create a local user profile from Firebase Auth data
      return _createLocalUserProfile(firebaseUser);
    }
  }

  /// Create a local user profile from Firebase Auth user data
  UserModel _createLocalUserProfile(User firebaseUser) {
    // Generate SPP ID: SPP + 8 numeric digits derived from UID
    final numericUid = firebaseUser.uid.codeUnits.join('').substring(0, 8);
    final sppId = 'SPP$numericUid';
    
    return UserModel(
      uid: firebaseUser.uid,
      spPId: sppId,
      email: firebaseUser.email ?? '',
      phoneNumber: firebaseUser.phoneNumber ?? '',
      name: firebaseUser.displayName ?? '',
      role: 'player',
      battingStyle: 'right-hand',
      bowlingStyle: 'medium',
      age: 0,
      location: '',
      profileImageUrl: firebaseUser.photoURL ?? '',
      instagramUrl: '',
      isVerified: firebaseUser.emailVerified,
      isProfileComplete: false,
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      tennisBallStats: PlayerStats(matches: 0, runs: 0, wickets: 0, strikeRate: 0, economy: 0, bestScore: 0, bestBowling: '0/0', manOfMatches: 0, tournamentWins: 0),
      leatherBallStats: PlayerStats(matches: 0, runs: 0, wickets: 0, strikeRate: 0, economy: 0, bestScore: 0, bestBowling: '0/0', manOfMatches: 0, tournamentWins: 0),
    );
  }

  // ==================== PHONE AUTHENTICATION ====================
  
  // Note: Firebase handles reCAPTCHA automatically on web.
  // The invisible reCAPTCHA is used by default when Firebase Auth SDK detects web platform.
  // Make sure 'recaptcha-container' div exists in index.html for fallback scenarios.

  /// Start phone number verification
  Future<void> signInWithPhone(String phoneNumber) async {
    debugPrint('📱 Sending OTP to $phoneNumber');
    
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification on Android
        debugPrint('✅ Auto-verification completed');
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('❌ Phone verification failed: ${e.message}');
        throw Exception(e.message ?? 'Phone verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        debugPrint('📨 OTP sent successfully');
        _verificationId = verificationId;
        _resendToken = resendToken;
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Verify phone OTP
  Future<UserModel> verifyOtp(String phoneNumber, String otp) async {
    if (_verificationId == null) {
      throw Exception('No verification in progress. Please request OTP first.');
    }
    
    debugPrint('🔐 Verifying OTP...');
    
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        throw Exception('Sign in failed');
      }
      
      _currentUser = await _loadUserProfile(userCredential.user!);
      _authStateController.add(_currentUser);
      _verificationId = null;
      
      debugPrint('✅ Phone OTP verified successfully');
      return _currentUser!;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code' || e.code == 'invalid-credential') {
        throw Exception('Invalid OTP');
      }
      throw Exception(e.message ?? 'Failed to verify OTP');
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }

  // ==================== EMAIL AUTHENTICATION ====================

  /// Send email sign-in link (passwordless)
  Future<void> signInWithEmail(String email) async {
    debugPrint('📧 Sending sign-in link to $email');
    
    // For web, we'll use email/password with a generated OTP-style password
    // In production, use sendSignInLinkToEmail for true passwordless auth
    
    // Store email for verification step
    // Since email link requires deep linking setup, we'll use a simpler approach:
    // Create account with email and send password reset, or use email+OTP simulation
    
    try {
      // Note: fetchSignInMethodsForEmail is removed in newer Firebase Auth.
      // We proceed directly - the sign-in/sign-up step will handle new vs existing users.
      debugPrint('📧 Checking email: $email');
      
      // For now, we'll use a simple approach - email OTP will be verified in the next step
      debugPrint('📧 Email verification initiated for $email');
      
    } catch (e) {
      debugPrint('❌ Email auth error: $e');
      throw Exception('Failed to initiate email sign-in: $e');
    }
  }

  /// Verify email with OTP (simplified - creates/signs in user)
  Future<UserModel> verifyEmailOtp(String email, String otp) async {
    debugPrint('🔐 Verifying email OTP for $email');
    
    try {
      // Use OTP as password for simplified auth flow
      // In production, implement proper email link verification
      UserCredential userCredential;
      
      try {
        // Try to sign in existing user
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: otp,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          // Create new user
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: otp,
          );
        } else {
          rethrow;
        }
      }
      
      if (userCredential.user == null) {
        throw Exception('Sign in failed');
      }
      
      _currentUser = await _loadUserProfile(userCredential.user!);
      _authStateController.add(_currentUser);
      
      debugPrint('✅ Email verified successfully');
      return _currentUser!;
      
    } catch (e) {
      debugPrint('❌ Email verification error: $e');
      throw Exception('Email verification failed: $e');
    }
  }

  // ==================== EMAIL + PASSWORD ====================

  /// Sign in or Sign up with Email and Password
  Future<UserModel> signInWithEmailPassword(String email, String password, {bool isSignUp = false}) async {
    debugPrint('📧 ${isSignUp ? "Signing up" : "Signing in"} with email: $email');
    
    try {
      UserCredential userCredential;
      
      if (isSignUp) {
        // Create new account
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint('✅ Account created successfully');
      } else {
        // Sign in existing user
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint('✅ Signed in successfully');
      }
      
      if (userCredential.user == null) {
        throw Exception('Authentication failed');
      }
      
      _currentUser = await _loadUserProfile(userCredential.user!);
      _authStateController.add(_currentUser);
      
      return _currentUser!;
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Auth error: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email. Please sign up.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
        case 'INVALID_LOGIN_CREDENTIALS':
        case 'invalid_login_credentials':
          errorMessage = 'Invalid email or password. Please try again.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email. Please sign in.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        default:
          if (e.message != null && e.message!.toLowerCase().contains('supplied auth credentials')) {
            errorMessage = 'Invalid email or password. Please try again.';
          } else {
            errorMessage = e.message ?? 'Authentication failed';
          }
      }
      throw Exception(errorMessage);
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      throw Exception('Authentication failed: $e');
    }
  }

  // ==================== GOOGLE SIGN-IN ====================

  /// Sign in with Google
  Future<UserModel> signInWithGoogle() async {
    debugPrint('🔵 Starting Google Sign-In...');
    
    try {
      // Trigger the Google Sign-In flow (7.x API)
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      
      if (googleUser == null) {
        throw Exception('Google Sign-In cancelled');
      }
      
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      // Create a new credential (v7.x: accessToken no longer available, use idToken only)
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      
      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        throw Exception('Google Sign-In failed');
      }
      
      _currentUser = await _loadUserProfile(userCredential.user!);
      _authStateController.add(_currentUser);
      
      debugPrint('✅ Google Sign-In successful');
      return _currentUser!;
      
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      throw Exception('Google Sign-In failed: $e');
    }
  }

  // ==================== USER PROFILE ====================

  /// Update user profile in Firestore
  Future<void> updateUserProfile(UserModel user) async {
    debugPrint('💾 Updating profile for ${user.uid}');
    
    final updatedUser = user.copyWith(
      isProfileComplete: true,
      lastActiveAt: DateTime.now(),
    );
    
    await _firestore.collection('users').doc(user.uid).set(
      updatedUser.toMap(),
      SetOptions(merge: true),
    );
    
    _currentUser = updatedUser;
    _authStateController.add(_currentUser);
  }

  /// Get user by ID from Firestore
  Future<UserModel?> getUserById(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return UserModel.fromMap({...doc.data()!, 'uid': userId});
    }
    return null;
  }

  // ==================== SIGN OUT ====================

  /// Sign out from all providers
  Future<void> signOut() async {
    debugPrint('👋 Signing out...');
    
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint('Google sign-out error: $e');
    }
    
    await _auth.signOut();
    _currentUser = null;
    _verificationId = null;
    _authStateController.add(null);
    
    debugPrint('✅ Signed out successfully');
  }

  void dispose() {
    _authStateController.close();
  }
}
