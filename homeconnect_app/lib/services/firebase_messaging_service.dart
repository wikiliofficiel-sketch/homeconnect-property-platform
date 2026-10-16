// ============================================================
// FIREBASE PUSH NOTIFICATIONS
//
// SETUP REQUIS (une seule fois) :
// 1. Créer un projet sur https://console.firebase.google.com
// 2. Ajouter l'app Android (package: immo_benin)
// 3. Télécharger google-services.json → placer dans android/app/
// 4. Ajouter l'app iOS → télécharger GoogleService-Info.plist → ios/Runner/
// 5. Décommenter les packages dans pubspec.yaml :
//      firebase_core: ^3.0.0
//      firebase_messaging: ^15.0.0
// 6. Dans android/app/build.gradle, ajouter :
//      apply plugin: 'com.google.gms.google-services'
// 7. Dans android/build.gradle, ajouter dans dependencies :
//      classpath 'com.google.gms:google-services:4.4.0'
// 8. Décommenter les imports et le code ci-dessous
// ============================================================

// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'notification_service.dart'; // décommenter avec Firebase
import 'package:flutter/foundation.dart';

// Handler en arrière-plan (top-level function obligatoire)
// @pragma('vm:entry-point')
// Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   await NotificationService.addNotification(
//     userId: 0,
//     title: message.notification?.title ?? 'Notification',
//     body: message.notification?.body ?? '',
//     type: message.data['type'] ?? 'info',
//   );
// }

class FirebaseMessagingService {
  // static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static String? _fcmToken;

  static String? get fcmToken => _fcmToken;

  static Future<void> init() async {
    // await Firebase.initializeApp();
    // FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    // await _requestPermission();
    // await _getToken();
    // _listenForeground();
    debugPrint('[Firebase] Service non configuré — voir les instructions en tête de fichier');
  }

  // static Future<void> _requestPermission() async {
  //   final settings = await _messaging.requestPermission(
  //     alert: true,
  //     badge: true,
  //     sound: true,
  //   );
  //   debugPrint('[Firebase] Permission: ${settings.authorizationStatus}');
  // }

  // static Future<void> _getToken() async {
  //   _fcmToken = await _messaging.getToken();
  //   debugPrint('[Firebase] FCM Token: $_fcmToken');
  //   _messaging.onTokenRefresh.listen((token) => _fcmToken = token);
  // }

  // static void _listenForeground() {
  //   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  //     NotificationService.addNotification(
  //       userId: 0,
  //       title: message.notification?.title ?? 'Notification',
  //       body: message.notification?.body ?? '',
  //       type: message.data['type'] ?? 'info',
  //     );
  //   });
  // }

  static Future<String?> getToken() async {
    return null;
  }
}
