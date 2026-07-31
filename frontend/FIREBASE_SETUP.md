# Firebase Setup Guide for ScorePartner

## 1. Firebase Project Setup

### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: "ScorePartner"
4. Enable Google Analytics (optional)
5. Click "Create project"

### Add Android App
1. In Firebase Console, click Android icon
2. Package name: `com.scorepartner.app`
3. Download `google-services.json`
4. Place it in `android/app/google-services.json`

### Add iOS App (if needed)
1. Click iOS icon
2. Bundle ID: `com.scorepartner.app`
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/GoogleService-Info.plist`

## 2. Enable Firebase Services

### Authentication
1. Go to Authentication → Sign-in method
2. Enable "Phone" provider
3. Configure phone number settings

### Firestore Database
1. Go to Firestore Database
2. Create database in "Test mode" (for development)
3. Choose location nearest to your users
4. Start in test mode (rules will be updated later)

### Storage
1. Go to Storage
2. Get started
3. Start in test mode (rules will be updated later)
4. Choose location

### Cloud Messaging
1. Go to Cloud Messaging
2. Upload APNS certificate (for iOS)
3. Configure Android settings

## 3. Install Dependencies

Run these commands in your project root:

```bash
flutter pub add firebase_core
flutter pub add firebase_auth
flutter pub add cloud_firestore
flutter pub add firebase_storage
flutter pub add firebase_messaging
flutter pub add firebase_phone_auth_handler
flutter pub add flutter_local_notifications
flutter pub add image_picker
flutter pub add provider
flutter pub add flutter_tts
flutter pub add video_player
flutter pub add cached_network_image
flutter pub add permission_handler
flutter pub add shared_preferences
flutter pub add http
flutter pub add dio
flutter pub add intl
flutter pub add uuid
flutter pub add url_launcher
flutter pub add shimmer
flutter pub add lottie
```

## 4. Android Configuration

### android/app/build.gradle
```gradle
android {
    // ...
    defaultConfig {
        // ...
        multiDexEnabled true
    }
}

dependencies {
    // ...
    implementation 'com.google.firebase:firebase-bom:32.7.0'
    implementation 'com.google.firebase:firebase-analytics'
    implementation 'com.google.firebase:firebase-auth'
    implementation 'com.google.firebase:firebase-firestore'
    implementation 'com.google.firebase:firebase-storage'
    implementation 'com.google.firebase:firebase-messaging'
}
```

### android/build.gradle
```gradle
buildscript {
    dependencies {
        // ...
        classpath 'com.google.gms:google-services:4.4.0'
        classpath 'com.google.firebase:firebase-crashlytics-gradle:2.9.9'
    }
}
```

### android/app/src/main/AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />

<application>
    <!-- Add this inside application tag -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_icon"
        android:resource="@drawable/ic_notification" />
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_color"
        android:resource="@color/colorAccent" />
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_channel_id"
        android:value="scorepartner_channel" />
</application>
```

## 5. iOS Configuration

### ios/Runner/Info.plist
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to upload profile pictures and reels</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for video recording</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select images</string>
```

### ios/Podfile
```ruby
# Uncomment this line
platform :ios, '12.0'

# Add these pods
pod 'Firebase/Core'
pod 'Firebase/Auth'
pod 'Firebase/Firestore'
pod 'Firebase/Storage'
pod 'Firebase/Messaging'
pod 'Firebase/Analytics'
```

## 6. Generate Firebase Options

Run this command to generate firebase_options.dart:

```bash
flutterfire configure
```

This will create `lib/firebase_options.dart` with your project configuration.

## 7. Initialize Firebase in App

### lib/main.dart
```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ScorePartnerApp());
}
```

## 8. Security Rules

### Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null;
    }
    
    // Matches - public read, creator write
    match /matches/{matchId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        request.auth.uid == resource.data.createdBy;
    }
    
    // Tournaments - public read, organizer write
    match /tournaments/{tournamentId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        request.auth.uid == resource.data.organizerId;
    }
    
    // Reels - public read, owner write
    match /reels/{reelId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        request.auth.uid == resource.data.playerId;
    }
  }
}
```

### Storage Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /{allPaths=**} {
    allow read, write: if request.auth != null;
  }
  
  // Profile images
  match /profiles/{userId}/{allPaths=**} {
    allow read: if true;
    allow write: if request.auth != null && request.auth.uid == userId;
  }
  
  // Reels
  match /reels/{userId}/{allPaths=**} {
    allow read: if true;
    allow write: if request.auth != null && request.auth.uid == userId;
  }
}
```

## 9. Testing the Setup

### Test Authentication
```dart
import 'package:firebase_auth/firebase_auth.dart';

// Test phone auth
final auth = FirebaseAuth.instance;
await auth.signInWithPhoneNumber('+1234567890');
```

### Test Firestore
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

final firestore = FirebaseFirestore.instance;
await firestore.collection('test').add({'test': 'data'});
```

### Test Storage
```dart
import 'package:firebase_storage/firebase_storage.dart';

final storage = FirebaseStorage.instance;
final ref = storage.ref().child('test.txt');
await ref.putString('Hello Firebase');
```

## 10. Common Issues & Solutions

### Issues:
1. **"Missing google-services.json"** - Download from Firebase Console
2. **"Network error"** - Check internet connection and Firebase rules
3. **"Permission denied"** - Update security rules
4. **"Build failed"** - Clean and rebuild project

### Solutions:
```bash
# Clean Flutter
flutter clean
flutter pub get

# For Android
cd android
./gradlew clean
cd ..

# For iOS
cd ios
pod clean
pod install
cd ..
```

## 11. Production Checklist

- [ ] Change Firestore rules to production mode
- [ ] Set up proper indexing in Firestore
- [ ] Configure Firebase Analytics
- [ ] Set up Crashlytics
- [ ] Configure App Distribution
- [ ] Set up Performance Monitoring
- [ ] Configure Remote Config
- [ ] Set up A/B Testing (if needed)

## 12. Next Steps

1. Run `flutter pub get` to install all dependencies
2. Test Firebase initialization
3. Implement authentication flow
4. Set up database operations
5. Configure push notifications
6. Test file uploads
7. Deploy to testing environments
