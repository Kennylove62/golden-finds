import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore {
    return _firestoreOverride ?? FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>> get _notifications {
    return _firestore.collection('notifications');
  }

  Stream<List<AppNotification>> watchNotifications(String userId) {
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty) {
      throw Exception('User account is invalid.');
    }

    return _notifications
        .where('recipientId', isEqualTo: cleanUserId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map(AppNotification.fromDocument)
              .toList();

          notifications.sort((a, b) => _compareDates(b.createdAt, a.createdAt));

          return notifications;
        });
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.read) {
      return;
    }

    await _notifications.doc(notification.id).update({'read': true});
  }

  Future<void> markAllRead(String userId) async {
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty) {
      throw Exception('User account is invalid.');
    }

    final snapshot = await _notifications
        .where('recipientId', isEqualTo: cleanUserId)
        .get();

    final unread = snapshot.docs.where(
      (document) => document.data()['read'] != true,
    );

    if (unread.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final document in unread) {
      batch.update(document.reference, {'read': true});
    }

    await batch.commit();
  }

  int _compareDates(DateTime? first, DateTime? second) {
    if (first == null && second == null) {
      return 0;
    }

    if (first == null) {
      return 1;
    }

    if (second == null) {
      return -1;
    }

    return first.compareTo(second);
  }
}
