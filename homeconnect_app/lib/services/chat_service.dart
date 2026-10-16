// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';

class ChatService {
  // Mock implementation - replace with Firebase when available
  // static final _firestore = FirebaseFirestore.instance;

  static Stream<List<ChatMessage>> getMessages(String currentUser, String otherUser) {
    // Return empty stream for mock implementation
    return Stream.value([]);
  }

  static Future<void> sendMessage(String currentUser, String otherUser, String text) async {
    // Mock implementation - replace with Firebase when available
    debugPrint('[Chat] sendMessage: $currentUser → $otherUser: $text');
  }
}