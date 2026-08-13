// File generated based on Firebase console web app configuration
// This file contains Firebase configuration options for different platforms

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBXcueTXGHoYEmpiD_R_f80rB6oEIY5Zdg',
    appId: '1:685168729318:web:ea72a840c2a3d635976f27',
    messagingSenderId: '685168729318',
    projectId: 'scorepatner',
    authDomain: 'scorepatner.firebaseapp.com',
    storageBucket: 'scorepatner.firebasestorage.app',
    measurementId: 'G-KXD40X4KF2',
  );

  // Android configuration (from google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCjKeVyf8_rojAcyYSLLMYQTxhf672YLZk',
    appId: '1:685168729318:android:e979c84585d13ab4976f27',
    messagingSenderId: '685168729318',
    projectId: 'scorepatner',
    storageBucket: 'scorepatner.firebasestorage.app',
  );

  // iOS configuration (configured in Firebase console)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCjKeVyf8_rojAcyYSLLMYQTxhf672YLZk',
    appId: '1:685168729318:ios:e979c84585d13ab4976f27',
    messagingSenderId: '685168729318',
    projectId: 'scorepatner',
    storageBucket: 'scorepatner.firebasestorage.app',
    iosBundleId: 'com.scorepatner.app',
  );

  // macOS configuration
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCjKeVyf8_rojAcyYSLLMYQTxhf672YLZk',
    appId: '1:685168729318:macos:e979c84585d13ab4976f27',
    messagingSenderId: '685168729318',
    projectId: 'scorepatner',
    storageBucket: 'scorepatner.firebasestorage.app',
    iosBundleId: 'com.scorepatner.app',
  );

  // Windows configuration
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCjKeVyf8_rojAcyYSLLMYQTxhf672YLZk',
    appId: '1:685168729318:windows:e979c84585d13ab4976f27',
    messagingSenderId: '685168729318',
    projectId: 'scorepatner',
    storageBucket: 'scorepatner.firebasestorage.app',
  );
}
