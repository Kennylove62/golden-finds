import 'package:cloud_firestore/cloud_firestore.dart';

class CartService {
  CartService({FirebaseFirestore? firestore}) : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore {
    return _firestoreOverride ?? FirebaseFirestore.instance;
  }

  DocumentReference<Map<String, dynamic>> _cartDocument(String userId) {
    return _firestore.collection('carts').doc(userId);
  }

  Stream<Map<String, int>> watchCart(String userId) {
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty) {
      throw Exception('Client account is invalid.');
    }

    return _cartDocument(cleanUserId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return <String, int>{};
      }

      final rawItems = data['items'];

      if (rawItems is! Map) {
        return <String, int>{};
      }

      final cart = <String, int>{};

      for (final entry in rawItems.entries) {
        final productId = entry.key.toString().trim();
        final rawQuantity = entry.value;

        if (productId.isEmpty) {
          continue;
        }

        final quantity = rawQuantity is num
            ? rawQuantity.toInt()
            : int.tryParse(rawQuantity.toString()) ?? 0;

        if (quantity > 0) {
          cart[productId] = quantity;
        }
      }

      return cart;
    });
  }

  Future<void> setQuantity({
    required String userId,
    required String productId,
    required int quantity,
  }) async {
    final cleanUserId = userId.trim();
    final cleanProductId = productId.trim();

    if (cleanUserId.isEmpty) {
      throw Exception('Client account is invalid.');
    }

    if (cleanProductId.isEmpty) {
      throw Exception('Product ID is invalid.');
    }

    if (quantity < 0) {
      throw Exception('Cart quantity cannot be negative.');
    }

    if (quantity > 999) {
      throw Exception('Cart quantity is too large.');
    }

    final document = _cartDocument(cleanUserId);

    if (quantity == 0) {
      final snapshot = await document.get();

      if (!snapshot.exists) {
        return;
      }

      await document.update({
        'items.$cleanProductId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return;
    }

    try {
      await document.update({
        'items.$cleanProductId': quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') {
        rethrow;
      }

      await document.set({
        'items': <String, dynamic>{cleanProductId: quantity},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> clearCart(String userId) async {
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty) {
      throw Exception('Client account is invalid.');
    }

    await _cartDocument(cleanUserId).set({
      'items': <String, dynamic>{},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
