import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';

class AdvancedChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  final List<String> _typingUsers = [];
  final Map<int, DateTime> _readReceipts = {}; // messageId -> readTime
  bool _isLoading = false;
  String _error = '';
  final Map<int, List<int>> _deliveredTo = {}; // messageId -> list of userIds

  List<ChatMessage> get messages => _messages;
  List<String> get typingUsers => _typingUsers;
  Map<int, DateTime> get readReceipts => _readReceipts;
  bool get isLoading => _isLoading;
  String get error => _error;
  
  bool get hasUnreadMessages => _messages.any((m) => !m.isRead);
  int get unreadCount => _messages.where((m) => !m.isRead).length;

  // ========== BASIC MESSAGING ==========
  
  Future<void> loadMessages({
    required int userId1,
    required int userId2,
    int limit = 50,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final db = DatabaseHelper();
      final list = await db.getMessages(userId1, userId2);
      _messages = list.map((m) {
        // Conversion basique de Map vers ChatMessage
        return ChatMessage(
          id: m['id'],
          senderId: m['senderId'],
          receiverId: m['receiverId'],
          text: m['text'],
          timestamp: DateTime.parse(m['timestamp']),
          isRead: m['read'] ?? false,
          status: (m['read'] ?? false) ? MessageStatus.read : MessageStatus.sent,
        );
      }).toList();
      
      // Trier par date (le plus récent en premier pour ListView reversed)
      _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAdminMessages(int currentUserId) async {
    final admin = await DatabaseHelper().getAdminUser();
    if (admin != null) {
      await loadMessages(userId1: currentUserId, userId2: admin.id);
    } else {
      // Fallback to ID 1 if admin user not found (backward compatibility)
      await loadMessages(userId1: currentUserId, userId2: 1);
    }
  }

  Future<bool> sendMessage({
    required int senderId,
    required int receiverId,
    required String content,
    List<String>? attachments,
    List<Attachment>? attachmentObjects,
  }) async {
    try {
      if (content.isEmpty && (attachments?.isEmpty ?? true)) {
        _error = 'Le message ne peut pas être vide';
        notifyListeners();
        return false;
      }

      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch,
        senderId: senderId,
        receiverId: receiverId,
        text: content,
        timestamp: DateTime.now(),
        isRead: false,
        status: MessageStatus.sending,
        attachments: attachments,
        attachmentObjects: attachmentObjects,
        reactions: {},
      );

      // Sauvegarder en base locale
      final db = DatabaseHelper();
      await db.addMessage({
        'senderId': senderId,
        'receiverId': receiverId,
        'text': content,
        'timestamp': message.timestamp.toIso8601String(),
        'read': false,
      });

      // Envoyer via API si possible
      try {
        final isConnected = await ApiService.checkConnectivity();
        if (isConnected) {
          await ApiService.sendMessage(receiverId: receiverId, content: content);
        }
      } catch (e) {
        debugPrint('Erreur sync API chat: $e');
      }

      _messages.insert(0, message.copyWith(status: MessageStatus.sent));
      _deliveredTo[message.id] = [receiverId];
      notifyListeners();
      
      // Notify receiver (local simulation)
      NotificationService.addNotification(
        userId: receiverId,
        title: 'Nouveau message',
        body: content.length > 50 ? '${content.substring(0, 47)}...' : content,
        type: 'chat',
      );
      
      return true;
    } catch (e) {
      _error = 'Erreur lors de l\'envoi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendVoiceNote({
    required int senderId,
    required int receiverId,
    required String duration,
    required String filePath,
  }) async {
    try {
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch,
        senderId: senderId,
        receiverId: receiverId,
        text: 'Note vocale',
        timestamp: DateTime.now(),
        type: MessageType.voiceNote,
        duration: duration,
        status: MessageStatus.sent,
        attachmentObjects: [
          Attachment(
            id: 'vn_${DateTime.now().millisecondsSinceEpoch}',
            url: filePath,
            fileName: 'VoiceNote_$duration.aac',
            type: AttachmentType.audio,
            uploadedAt: DateTime.now(),
          )
        ],
      );

      _messages.insert(0, message); // Insérer au début pour ListView reversed
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Erreur vocal: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendMediaMessage({
    required int senderId,
    required int receiverId,
    required MessageType type,
    required String text,
    required Attachment attachment,
  }) async {
    try {
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch,
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        timestamp: DateTime.now(),
        type: type,
        status: MessageStatus.sent,
        attachmentObjects: [attachment],
      );

      _messages.insert(0, message);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Erreur média: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendCallLog({
    required int senderId,
    required int receiverId,
    required bool isVideo,
    required String duration,
  }) async {
    try {
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch,
        senderId: senderId,
        receiverId: receiverId,
        text: isVideo ? 'Appel vidéo' : 'Appel vocal',
        timestamp: DateTime.now(),
        type: isVideo ? MessageType.callVideo : MessageType.callVoice,
        duration: duration,
        status: MessageStatus.sent,
      );

      _messages.insert(0, message);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Erreur appel: $e';
      notifyListeners();
      return false;
    }
  }

  // ========== ADVANCED FEATURES ==========

  /// Ajouter une pièce jointe à un message
  Future<bool> addAttachment({
    required int messageId,
    required Attachment attachment,
  }) async {
    try {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final message = _messages[index];
        final updatedAttachments = [...?message.attachmentObjects, attachment];
        
        _messages[index] = message.copyWith(
          attachmentObjects: updatedAttachments,
        );
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Erreur lors de l\'ajout de pièce jointe: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Ajouter une réaction émoji à un message
  Future<bool> addReaction({
    required int messageId,
    required String emoji,
    required int userId,
  }) async {
    try {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final message = _messages[index];
        final reactions = Map<String, List<int>>.from(message.reactions ?? {});
        
        if (reactions.containsKey(emoji)) {
          if (!reactions[emoji]!.contains(userId)) {
            reactions[emoji]!.add(userId);
          }
        } else {
          reactions[emoji] = [userId];
        }
        
        _messages[index] = message.copyWith(reactions: reactions);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Erreur lors de l\'ajout de réaction: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Retirer une réaction
  Future<bool> removeReaction({
    required int messageId,
    required String emoji,
    required int userId,
  }) async {
    try {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final message = _messages[index];
        final reactions = Map<String, List<int>>.from(message.reactions ?? {});
        
        if (reactions.containsKey(emoji)) {
          reactions[emoji]!.removeWhere((id) => id == userId);
          if (reactions[emoji]!.isEmpty) {
            reactions.remove(emoji);
          }
        }
        
        _messages[index] = message.copyWith(reactions: reactions);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Erreur lors de la suppression de réaction: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Marquer un message comme lu
  Future<bool> markMessageAsRead(int messageId, int userId) async {
    try {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final message = _messages[index];
        if (!message.isRead) {
          final readTime = DateTime.now();
          _messages[index] = message.copyWith(
            isRead: true,
            readAt: readTime,
            status: MessageStatus.read,
          );
          
          _readReceipts[messageId] = readTime;
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _error = 'Erreur lors du marquage: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Marquer que le message a été livré
  Future<bool> markMessageAsDelivered(int messageId, int userId) async {
    try {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final message = _messages[index];
        if (message.status != MessageStatus.read && message.status != MessageStatus.delivered) {
          _messages[index] = message.copyWith(status: MessageStatus.delivered);
          _deliveredTo[messageId] = [...?_deliveredTo[messageId], userId];
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _error = 'Erreur lors du marquage: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Marquer tous les messages comme lus
  Future<bool> markAllAsRead(int userIdSender) async {
    try {
      bool anyUpdated = false;
      final readTime = DateTime.now();
      for (int i = 0; i < _messages.length; i++) {
        if (!_messages[i].isRead && _messages[i].senderId == userIdSender) {
          final message = _messages[i];
          _messages[i] = message.copyWith(
            isRead: true,
            readAt: readTime,
            status: MessageStatus.read,
          );
          _readReceipts[message.id] = readTime;
          anyUpdated = true;
        }
      }
      if (anyUpdated) notifyListeners();
      return anyUpdated;
    } catch (e) {
      _error = 'Erreur lors du marquage: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Indiquer qu'un utilisateur est en train de taper
  void setUserTyping(String userName, {bool isTyping = true}) {
    if (isTyping && !_typingUsers.contains(userName)) {
      _typingUsers.add(userName);
    } else if (!isTyping) {
      _typingUsers.remove(userName);
    }
    notifyListeners();
  }

  /// Chercher des messages
  List<ChatMessage> searchMessages(String query) {
    if (query.isEmpty) return _messages;
    
    return _messages
        .where((m) => m.text.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Obtenir les messages non lus
  List<ChatMessage> getUnreadMessages(int userId) {
    return _messages
        .where((m) => m.receiverId == userId && !m.isRead)
        .toList();
  }

  /// Supprimer un message
  Future<bool> deleteMessage(int messageId) async {
    try {
      _messages.removeWhere((m) => m.id == messageId);
      _readReceipts.remove(messageId);
      _deliveredTo.remove(messageId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Erreur lors de la suppression: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Éditer un message
  Future<bool> editMessage({
    required int messageId,
    required String newContent,
  }) async {
    try {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final message = _messages[index];
        _messages[index] = message.copyWith(
          text: newContent,
          isEdited: true,
          editedAt: DateTime.now(),
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Erreur lors de l\'édition: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Obtenir les statistiques de conversation
  Map<String, dynamic> getConversationStats({
    required int userId1,
    required int userId2,
  }) {
    final conversationMessages = _messages.where(
      (m) => (m.senderId == userId1 && m.receiverId == userId2) ||
             (m.senderId == userId2 && m.receiverId == userId1),
    ).toList();

    final sentByUser1 = conversationMessages.where((m) => m.senderId == userId1).length;
    final sentByUser2 = conversationMessages.where((m) => m.senderId == userId2).length;
    final unread = conversationMessages.where((m) => !m.isRead).length;
    final withAttachments = conversationMessages.where((m) => (m.attachmentObjects?.isNotEmpty ?? false) || (m.attachments?.isNotEmpty ?? false)).length;
    final withReactions = conversationMessages.where((m) => (m.reactions?.isNotEmpty ?? false)).length;

    return {
      'totalMessages': conversationMessages.length,
      'sentByUser1': sentByUser1,
      'sentByUser2': sentByUser2,
      'unread': unread,
      'withAttachments': withAttachments,
      'withReactions': withReactions,
      'firstMessage': conversationMessages.isNotEmpty ? conversationMessages.first.timestamp : null,
      'lastMessage': conversationMessages.isNotEmpty ? conversationMessages.last.timestamp : null,
    };
  }

  /// Exporter la conversation
  String exportConversation({
    required int userId1,
    required int userId2,
  }) {
    final conversationMessages = _messages.where(
      (m) => (m.senderId == userId1 && m.receiverId == userId2) ||
             (m.senderId == userId2 && m.receiverId == userId1),
    ).toList();

    StringBuffer export = StringBuffer();
    export.writeln('=== CONVERSATION EXPORT ===');
    export.writeln('Date d\'export: ${DateTime.now()}');
    export.writeln('Utilisateur 1: $userId1');
    export.writeln('Utilisateur 2: $userId2');
    export.writeln('Nombre de messages: ${conversationMessages.length}');
    export.writeln('');

    for (final message in conversationMessages) {
      final statusStr = message.status.toString().split('.').last;
      export.writeln('[${message.timestamp}] User ${message.senderId} ($statusStr): ${message.text}');
      if (message.attachmentObjects?.isNotEmpty ?? false) {
        export.writeln('  Attachments: ${message.attachmentObjects!.map((a) => a.fileName).join(", ")}');
      }
      if (message.isEdited) {
        export.writeln('  Edited: ${message.editedAt}');
      }
    }

    return export.toString();
  }

  /// Nettoyer les messages anciens
  Future<int> deleteOldMessages({required Duration olderThan}) async {
    try {
      final cutoffDate = DateTime.now().subtract(olderThan);
      final initialCount = _messages.length;
      
      _messages.removeWhere((m) => m.timestamp.isBefore(cutoffDate));
      
      final deletedCount = initialCount - _messages.length;
      notifyListeners();
      return deletedCount;
    } catch (e) {
      _error = 'Erreur lors du nettoyage: ${e.toString()}';
      notifyListeners();
      return 0;
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}
