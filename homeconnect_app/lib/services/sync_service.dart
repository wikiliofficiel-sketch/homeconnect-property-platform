import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// SyncService simplifié — l'API Symfony est la source de vérité.
/// Plus de bulk export/import qui mélangeait les données entre utilisateurs.
class SyncService {
  static bool _isSyncing = false;

  /// No-op conservé pour compatibilité des appels existants.
  /// L'app utilise désormais l'API directement pour chaque écran.
  static Future<void> autoSync() async {
    debugPrint('[SyncService] autoSync désactivé — données chargées depuis l\'API.');
  }

  /// Pull léger : vérifie juste que le serveur est joignable.
  /// Conservé pour compatibilité avec register().
  static Future<void> pullFromBackend() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final ok = await ApiService.checkConnectivity();
      debugPrint('[SyncService] Serveur ${ok ? "joignable" : "hors ligne"}.');
    } catch (_) {
    } finally {
      _isSyncing = false;
    }
  }
}
