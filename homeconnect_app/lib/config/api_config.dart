import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_secrets.dart';

class ApiConfig {
  static String get baseUrl {
    // URL injectée au build → priorité absolue
    if (AppSecrets.apiBaseUrl != 'http://localhost:8000') {
      return AppSecrets.apiBaseUrl;
    }

    if (kIsWeb) return 'http://127.0.0.1:8000';

    if (Platform.isAndroid) {
      // Hotspot Windows : 192.168.137.1 (IP fixe du partage de connexion PC)
      // WiFi normal : 192.168.0.100
      // Émulateur : 10.0.2.2
      return 'http://192.168.137.1:8000';
    }

    // iOS simulateur + desktop
    return 'http://localhost:8000';
  }
}
