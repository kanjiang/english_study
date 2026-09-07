import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        throw UnsupportedError(
          'Firebase is configured only for Android and iOS.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCm-P5d5HlDU3zV5iPONSq-LrMarxHYF4M',
    appId: '1:130607768761:android:ce0f9b8f3addce2dbaa768',
    messagingSenderId: '130607768761',
    projectId: 'english-study-kanjiang',
    storageBucket: 'english-study-kanjiang.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD5hpwS-o-_fciBBaWdqDu5OH-QyJGl1Vs',
    appId: '1:130607768761:ios:9e507870df967183baa768',
    messagingSenderId: '130607768761',
    projectId: 'english-study-kanjiang',
    storageBucket: 'english-study-kanjiang.firebasestorage.app',
    iosBundleId: 'com.xiaocixing.englishApp',
  );
}
