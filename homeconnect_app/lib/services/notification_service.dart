import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database_helper.dart';

class NotificationService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static const _key = 'notifications';

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _localNotifications.initialize(settings);
  }

  /// Récupère les notifications d'un utilisateur
  static Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    try {
      final db = DatabaseHelper();
      return await db.getNotifications(userId);
    } catch (e) {
      debugPrint('❌ Erreur getNotifications: $e');
      return [];
    }
  }

  /// Ajoute une nouvelle notification
  static Future<void> addNotification({
    required int userId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final notif = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      // Sauvegarder via DatabaseHelper
      final db = DatabaseHelper();
      await db.addNotification(userId, title, body, type);

      // Afficher notification locale
      await _showLocalNotification(notif);
      
      debugPrint('✅ Notification créée: $title');
    } catch (e) {
      debugPrint('❌ Erreur addNotification: $e');
    }
  }

  /// MÉTHODE PRINCIPALE : Envoyer notification
  static Future<void> envoyerNotification({
    required int userId,
    required String type, // candidature, paiement, plainte, securite
    required String message,
  }) async {
    String title;
    String iconType;

    switch (type) {
      case 'candidature':
        title = 'Mise à jour de votre demande';
        iconType = 'application';
        break;
      case 'paiement':
        title = 'Avis de paiement';
        iconType = 'payment';
        break;
      case 'plainte':
        title = 'Réponse à votre plainte';
        iconType = 'report';
        break;
      case 'securite':
        title = 'Alerte de sécurité';
        iconType = 'security';
        break;
      default:
        title = 'Nouvelle notification';
        iconType = 'info';
    }

    await addNotification(
      userId: userId,
      title: title,
      body: message,
      type: iconType,
    );
  }

  // --- HELPERS POUR NOTIFICATIONS AUTOMATIQUES ---

  static Future<void> sendApplicationConfirmation(int userId, String propertyTitle) async {
    await envoyerNotification(
      userId: userId,
      type: 'candidature',
      message: 'Votre demande de location pour "$propertyTitle" a été bien reçue et est en cours d\'examen.',
    );
  }

  static Future<void> sendPaymentNotice(int userId, int amount) async {
    await envoyerNotification(
      userId: userId,
      type: 'paiement',
      message: 'Un paiement de $amount FCFA a été traité avec succès sur votre compte.',
    );
  }

  static Future<void> sendComplaintResponse(int userId, String status) async {
    await envoyerNotification(
      userId: userId,
      type: 'plainte',
      message: 'L\'administration a répondu à votre plainte. Nouveau statut : $status.',
    );
  }

  /// Affiche une notification locale sur l'appareil
  static Future<void> _showLocalNotification(Map<String, dynamic> notif) async {
    try {
      final icon = _getIconForType(notif['type'] as String);
      final notifId = (notif['id'] as int).abs() % 2147483647;
      
      await _localNotifications.show(
        notifId,
        '$icon ${notif['title']}',
        notif['body'],
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'immo_benin_channel',
            'Immo Bénin',
            channelDescription: 'Notifications Immo Bénin',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Erreur affichage notification locale: $e');
    }
  }

  /// Retourne l'icône appropriée selon le type
  static String _getIconForType(String type) {
    switch (type) {
      case 'property':
        return '🏠';
      case 'application':
        return '📬';
      case 'profile':
        return '👤';
      case 'security':
        return '🔐';
      case 'kyc':
        return '🛡️';
      case 'payment':
        return '💰';
      case 'report':
        return '🚩';
      case 'partnership':
        return '🤝';
      default:
        return 'ℹ️';
    }
  }

  /// Marque une notification comme lue
  static Future<void> markAsRead(int notifId) async {
    try {
      final db = DatabaseHelper();
      final list = await db.getList(_key);
      final updated = list.map((e) {
        final n = e as Map<String, dynamic>;
        if (n['id'] == notifId) {
          return {...n, 'read': true};
        }
        return n;
      }).toList();
      await db.setList(_key, updated);
      debugPrint('✅ Notification $notifId marquée comme lue');
    } catch (e) {
      debugPrint('❌ Erreur markAsRead: $e');
    }
  }

  /// Supprime une notification
  static Future<void> deleteNotification(int notifId) async {
    try {
      final db = DatabaseHelper();
      final list = await db.getList(_key);
      list.removeWhere((e) {
        final n = e as Map<String, dynamic>;
        return n['id'] == notifId;
      });
      await db.setList(_key, list);
      debugPrint('✅ Notification $notifId supprimée');
    } catch (e) {
      debugPrint('❌ Erreur deleteNotification: $e');
    }
  }
}