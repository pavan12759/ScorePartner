import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'text', 'image'
  final String? imageUrl;
  final String? audioUrl;
  final int? duration; // Duration in seconds
  final String? replyToId;
  final String? replyToText;
  final bool isDeleted;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.type = 'text',
    this.imageUrl,
    this.audioUrl,
    this.duration,
    this.replyToId,
    this.replyToText,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'type': type,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'duration': duration,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'isDeleted': isDeleted,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      type: map['type'] ?? 'text',
      imageUrl: map['imageUrl'],
      audioUrl: map['audioUrl'],
      duration: map['duration'],
      replyToId: map['replyToId'],
      replyToText: map['replyToText'],
      isDeleted: map['isDeleted'] ?? false,
    );
  }
}
