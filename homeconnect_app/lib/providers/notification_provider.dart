import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;

  int get unreadCount => _unreadCount;
  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;

  /// Charge les notifications pour un utilisateur
  Future<void> loadNotifications(int userId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final db = DatabaseHelper();
      
      // Tentative de récupération locale
      _notifications = await db.getNotifications(userId);
      
      // Si vide, on tente un pull depuis le backend (Web -> Mobile)
      if (_notifications.isEmpty) {
        await SyncService.pullFromBackend();
        _notifications = await db.getNotifications(userId);
      }
      
      _unreadCount = _notifications.where((n) => n['read'] != true).length;
      debugPrint('✅ ${_notifications.length} notifications chargées ($_unreadCount non lues)');
    } catch (e) {
      debugPrint('❌ Erreur chargement notifications: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  /// Marque une notification comme lue
  Future<void> markAsRead(int notifId) async {
    try {
      await NotificationService.markAsRead(notifId);
      
      // Mettre à jour la liste locale
      final idx = _notifications.indexWhere((n) => n['id'] == notifId);
      if (idx != -1) {
        _notifications[idx]['read'] = true;
        _unreadCount = _notifications.where((n) => n['read'] != true).length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Erreur markAsRead: $e');
    }
  }

  /// Marque toutes les notifications comme lues
  Future<void> markAllAsRead(int userId) async {
    try {
      final db = DatabaseHelper();
      final list = await db.getList('notifications');
      final updated = list.map((e) {
        final n = e as Map<String, dynamic>;
        if (n['userId'] == userId && n['read'] != true) {
          return {...n, 'read': true};
        }
        return n;
      }).toList();
      await db.setList('notifications', updated);
      
      // Mettre à jour l'état local
      for (var n in _notifications) {
        n['read'] = true;
      }
      _unreadCount = 0;
      notifyListeners();
      debugPrint('✅ Toutes les notifications marquées comme lues');
    } catch (e) {
      debugPrint('❌ Erreur markAllAsRead: $e');
    }
  }

  /// Ajoute une notification localement et la déclenche
  Future<void> addNotification({
    required int userId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      // Ajouter via service
      await NotificationService.addNotification(
        userId: userId,
        title: title,
        body: body,
        type: type,
      );

      // Recharger les notifications
      await loadNotifications(userId);
      
      debugPrint('✅ Notification créée: $title');
    } catch (e) {
      debugPrint('❌ Erreur addNotification: $e');
    }
  }

  /// Supprime une notification
  Future<void> deleteNotification(int notifId) async {
    try {
      _notifications.removeWhere((n) => n['id'] == notifId);
      _unreadCount = _notifications.where((n) => n['read'] != true).length;
      notifyListeners();
      debugPrint('✅ Notification supprimée');
    } catch (e) {
      debugPrint('❌ Erreur deleteNotification: $e');
    }
  }

  /// Vide toutes les notifications
  void clearAll() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
    debugPrint('✅ Toutes les notifications supprimées');
  }
}