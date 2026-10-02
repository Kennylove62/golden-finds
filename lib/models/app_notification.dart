import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.type,
    required this.title,
    required this.message,
    required this.orderId,
    required this.read,
    this.createdAt,
  });

  final String id;
  final String recipientId;
  final String senderId;
  final String type;
  final String title;
  final String message;
  final String orderId;
  final bool read;
  final DateTime? createdAt;

  String get timeLabel {
    final value = createdAt;

    if (value == null) {
      return 'Just now';
    }

    final now = DateTime.now();
    final difference = now.difference(value);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours} h ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} d ago';
    }

    String two(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  factory AppNotification.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return AppNotification(
      id: document.id,
      recipientId: (data['recipientId'] ?? '').toString(),
      senderId: (data['senderId'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      orderId: (data['orderId'] ?? '').toString(),
      read: data['read'] is bool ? data['read'] as bool : false,
      createdAt: _dateFromValue(data['createdAt']),
    );
  }

  static DateTime? _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
