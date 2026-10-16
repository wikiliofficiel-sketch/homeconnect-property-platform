enum MessageStatus { sending, sent, delivered, read, failed }

enum MessageType { text, image, video, sticker, document, voiceNote, callVoice, callVideo }

enum AttachmentType { image, video, audio, document, file }

class Attachment {
  final String id;
  final String url;
  final String fileName;
  final AttachmentType type;
  final int? fileSize;
  final String? mimeType;
  final DateTime uploadedAt;

  Attachment({
    required this.id,
    required this.url,
    required this.fileName,
    required this.type,
    this.fileSize,
    this.mimeType,
    required this.uploadedAt,
  });

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      id: map['id'] as String,
      url: map['url'] as String,
      fileName: map['fileName'] as String,
      type: AttachmentType.values[map['type'] as int? ?? 0],
      fileSize: map['fileSize'] as int?,
      mimeType: map['mimeType'] as String?,
      uploadedAt: DateTime.parse(map['uploadedAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'fileName': fileName,
      'type': type.index,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? deliveredAt;
  final MessageStatus status;
  final List<String>? attachments; // Legacy path support
  final List<Attachment>? attachmentObjects;
  final Map<String, List<int>>? reactions;
  final bool isEdited;
  final DateTime? editedAt;
  final MessageType type;
  final String? duration; // Pour les vocaux et appels

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.readAt,
    this.deliveredAt,
    this.status = MessageStatus.sent,
    this.attachments,
    this.attachmentObjects,
    this.reactions,
    this.isEdited = false,
    this.editedAt,
    this.type = MessageType.text,
    this.duration,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int,
      senderId: map['senderId'] as int,
      receiverId: map['receiverId'] as int,
      text: map['text'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: map['isRead'] as bool? ?? false,
      readAt: map['readAt'] != null ? DateTime.parse(map['readAt'] as String) : null,
      deliveredAt: map['deliveredAt'] != null ? DateTime.parse(map['deliveredAt'] as String) : null,
      status: MessageStatus.values[map['status'] as int? ?? 1],
      attachments: List<String>.from(map['attachments'] ?? []),
      attachmentObjects: (map['attachmentObjects'] as List?)
          ?.map((a) => Attachment.fromMap(a as Map<String, dynamic>))
          .toList(),
      reactions: (map['reactions'] as Map?)?.cast<String, List<int>>(),
      isEdited: map['isEdited'] as bool? ?? false,
      editedAt: map['editedAt'] != null ? DateTime.parse(map['editedAt'] as String) : null,
      type: MessageType.values[map['type'] as int? ?? 0],
      duration: map['duration'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'status': status.index,
      'attachments': attachments,
      'attachmentObjects': attachmentObjects?.map((a) => a.toMap()).toList(),
      'reactions': reactions,
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'type': type.index,
      'duration': duration,
    };
  }

  ChatMessage copyWith({
    int? id,
    int? senderId,
    int? receiverId,
    String? text,
    DateTime? timestamp,
    bool? isRead,
    DateTime? readAt,
    DateTime? deliveredAt,
    MessageStatus? status,
    List<String>? attachments,
    List<Attachment>? attachmentObjects,
    Map<String, List<int>>? reactions,
    bool? isEdited,
    DateTime? editedAt,
    MessageType? type,
    String? duration,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      attachmentObjects: attachmentObjects ?? this.attachmentObjects,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      type: type ?? this.type,
      duration: duration ?? this.duration,
    );
  }
}