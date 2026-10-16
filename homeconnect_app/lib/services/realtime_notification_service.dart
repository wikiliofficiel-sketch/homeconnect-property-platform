// import 'package:web_socket_channel/web_socket_channel.dart';

/// Service pour les notifications en temps réel via WebSocket
/// NOTE: Nécessite 'web_socket_channel' dans pubspec.yaml
class RealtimeNotificationService {
  static const String wsUrl = 'wss://api.homeconnect.local/ws';
  
  // static WebSocketChannel? _channel;

  /// Connecter WebSocket (stub - à implémenter avec web_socket_channel)
  static Future<bool> connect(String userId, String token) async {
    try {
      // _channel = WebSocketChannel.connect(
      //   Uri.parse('$wsUrl?userId=$userId&token=$token'),
      // );
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Envoyer un message via WebSocket
  static void send(Map<String, dynamic> data) {
    // if (_channel != null) {
    //   _channel!.sink.add(jsonEncode(data));
    // }
  }

  /// Envoyer une notification
  static void sendNotification({
    required String type, // candidature, message, paiement, litige
    required Map<String, dynamic> payload,
  }) {
    send({
      'type': 'notification',
      'eventType': type,
      'data': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Envoyer un message de chat
  static void sendChatMessage({
    required int receiverId,
    required String content,
  }) {
    send({
      'type': 'chat',
      'receiverId': receiverId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Rejoindre un canal (ex: candidatures d'une propriété)
  static void joinChannel(String channelName) {
    send({
      'type': 'subscribe',
      'channel': channelName,
    });
  }

  /// Quitter un canal
  static void leaveChannel(String channelName) {
    send({
      'type': 'unsubscribe',
      'channel': channelName,
    });
  }

  /// Déconnecter
  static Future<void> disconnect() async {
    // await _channel?.sink.close();
    // _channel = null;
  }

  /// Écouter les notifications
  static void onNotification(Function(Map<String, dynamic>) callback) {
  }

  /// Écouter les erreurs
  static void onError(Function(String) callback) {
  }

  /// Écouter la connexion
  static void onConnected(Function() callback) {
  }

  /// Vérifier connexion
  static bool get isConnected => true;
}

/// Types de notifications
enum NotificationType {
  candidatureRecue,
  candidatureAcceptee,
  candidatureRejetee,
  nouveauMessage,
  paiementRecu,
  litageSignale,
  evaluationRecue,
  signalementApprouve,
  propertyVerified,
}

extension NotificationTypeExtension on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.candidatureRecue:
        return 'candidature_recue';
      case NotificationType.candidatureAcceptee:
        return 'candidature_acceptee';
      case NotificationType.candidatureRejetee:
        return 'candidature_rejetee';
      case NotificationType.nouveauMessage:
        return 'nouveau_message';
      case NotificationType.paiementRecu:
        return 'paiement_recu';
      case NotificationType.litageSignale:
        return 'litige_signale';
      case NotificationType.evaluationRecue:
        return 'evaluation_recue';
      case NotificationType.signalementApprouve:
        return 'signalement_approuve';
      case NotificationType.propertyVerified:
        return 'propriete_verifiee';
    }
  }

  String get displayName {
    switch (this) {
      case NotificationType.candidatureRecue:
        return 'Nouvelle candidature';
      case NotificationType.candidatureAcceptee:
        return 'Candidature acceptée ✅';
      case NotificationType.candidatureRejetee:
        return 'Candidature rejetée ❌';
      case NotificationType.nouveauMessage:
        return 'Nouveau message 💬';
      case NotificationType.paiementRecu:
        return 'Paiement reçu 💰';
      case NotificationType.litageSignale:
        return 'Litige signalé 🚨';
      case NotificationType.evaluationRecue:
        return 'Vous avez reçu une évaluation ⭐';
      case NotificationType.signalementApprouve:
        return 'Signalement approuvé ✅';
      case NotificationType.propertyVerified:
        return 'Propriété vérifiée ✅';
    }
  }

  String get icon {
    switch (this) {
      case NotificationType.candidatureRecue:
        return '📮';
      case NotificationType.candidatureAcceptee:
        return '✅';
      case NotificationType.candidatureRejetee:
        return '❌';
      case NotificationType.nouveauMessage:
        return '💬';
      case NotificationType.paiementRecu:
        return '💰';
      case NotificationType.litageSignale:
        return '🚨';
      case NotificationType.evaluationRecue:
        return '⭐';
      case NotificationType.signalementApprouve:
        return '✅';
      case NotificationType.propertyVerified:
        return '✓';
    }
  }
}
