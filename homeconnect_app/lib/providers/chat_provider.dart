import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';

class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  void loadChat(String currentUid, String otherUid) {
    _isLoading = true; notifyListeners();
    ChatService.getMessages(currentUid, otherUid).listen((msgs) {
      _messages = msgs;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> sendMessage(String currentUid, String otherUid, String text) async {
    await ChatService.sendMessage(currentUid, otherUid, text);
    
    // 🔔 Envoyer une notification automatique au destinataire
    try {
      final recipientId = int.tryParse(otherUid) ?? 0;
      if (recipientId > 0) {
        await NotificationService.addNotification(
          userId: recipientId,
          title: 'Nouveau message',
          body: text.length > 50 ? '${text.substring(0, 50)}...' : text,
          type: 'message_received',
        );
      }
    } catch (e) {
      debugPrint('Erreur notification message: $e');
    }
  }
}