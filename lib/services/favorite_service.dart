import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteService {
  FavoriteService({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore {
    return _firestoreOverride ?? FirebaseFirestore.instance;
  }

  DocumentReference<Map<String, dynamic>> _favoriteDocument(String userId) {
    return _firestore.collection('favorites').doc(userId);
  }

  Stream<Set<String>> watchFavorites(String userId) {
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty) {
      throw Exception('Client account is invalid.');
    }

    return _favoriteDocument(cleanUserId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return <String>{};
      }

      final rawProductIds = data['productIds'];

      if (rawProductIds is! List) {
        return <String>{};
      }

      return rawProductIds
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet();
    });
  }

  Future<void> setFavorite({
    required String userId,
    required String productId,
    required bool favorite,
  }) async {
    final cleanUserId = userId.trim();
    final cleanProductId = productId.trim();

    if (cleanUserId.isEmpty) {
      throw Exception('Client account is invalid.');
    }

    if (cleanProductId.isEmpty) {
      throw Exception('Product ID is invalid.');
    }

    final document = _favoriteDocument(cleanUserId);

    if (favorite) {
      await document.set({
        'productIds': FieldValue.arrayUnion([cleanProductId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return;
    }

    final snapshot = await document.get();

    if (!snapshot.exists) {
      return;
    }

    await document.update({
      'productIds': FieldValue.arrayRemove([cleanProductId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearFavorites(String userId) async {
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty) {
      throw Exception('Client account is invalid.');
    }

    await _favoriteDocument(cleanUserId).set({
      'productIds': <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
