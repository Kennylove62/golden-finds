import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import 'currency_service.dart';

class OrderService {
  OrderService({FirebaseFirestore? firestore}) : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore {
    return _firestoreOverride ?? FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>> get _orders {
    return _firestore.collection('orders');
  }

  CollectionReference<Map<String, dynamic>> get _products {
    return _firestore.collection('products');
  }

  CollectionReference<Map<String, dynamic>> get _notifications {
    return _firestore.collection('notifications');
  }

  DocumentReference<Map<String, dynamic>> _cartDocument(String userId) {
    return _firestore.collection('carts').doc(userId);
  }

  Stream<List<OrderModel>> watchClientOrders(String clientId) {
    final cleanClientId = clientId.trim();

    if (cleanClientId.isEmpty) {
      throw Exception('Client account is invalid.');
    }

    return _orders.where('clientId', isEqualTo: cleanClientId).snapshots().map((
      snapshot,
    ) {
      final orders = snapshot.docs.map(OrderModel.fromDocument).toList();

      orders.sort((a, b) => _compareDates(b.createdAt, a.createdAt));

      return orders;
    });
  }

  Stream<List<OrderModel>> watchSellerOrders(String sellerId) {
    final cleanSellerId = sellerId.trim();

    if (cleanSellerId.isEmpty) {
      throw Exception('Seller account is invalid.');
    }

    return _orders.where('sellerId', isEqualTo: cleanSellerId).snapshots().map((
      snapshot,
    ) {
      final orders = snapshot.docs.map(OrderModel.fromDocument).toList();

      orders.sort((a, b) => _compareDates(b.createdAt, a.createdAt));

      return orders;
    });
  }

  Future<List<String>> checkoutCart({
    required AppUser client,
    required List<ProductModel> products,
    required Map<String, int> quantities,
    required String currency,
    required String deliveryOption,
    required String deliveryLocation,
    required String deliveryPhone,
    required String deliveryNotes,
    required String paymentMethod,
    required String paymentStatus,
  }) async {
    if (client.role.trim().toLowerCase() != 'client') {
      throw Exception('Only client accounts can place orders.');
    }

    if (client.uid.trim().isEmpty) {
      throw Exception('Client account is invalid.');
    }

    final cleanCurrency = currency.trim().toUpperCase();
    final cleanDeliveryOption = deliveryOption.trim().toLowerCase();
    final cleanLocation = deliveryLocation.trim();
    final cleanPhone = deliveryPhone.trim();
    final cleanNotes = deliveryNotes.trim();
    final cleanPaymentMethod = paymentMethod.trim().toLowerCase();
    final cleanPaymentStatus = paymentStatus.trim().toLowerCase();

    if (!CurrencyService.supportedCurrencies.contains(cleanCurrency)) {
      throw Exception('Select a valid checkout currency.');
    }

    if (!const {'delivery', 'pickup'}.contains(cleanDeliveryOption)) {
      throw Exception('Select delivery or physical boutique pickup.');
    }

    if (cleanDeliveryOption == 'delivery') {
      if (cleanLocation.length < 3) {
        throw Exception('Enter a valid delivery location/address.');
      }

      if (cleanPhone.length < 5) {
        throw Exception('Enter a valid delivery phone number.');
      }
    }

    if (!const {'mobile_money', 'bank_card'}.contains(cleanPaymentMethod)) {
      throw Exception('Select a simulated payment method.');
    }

    if (cleanPaymentStatus != 'paid') {
      throw Exception(
        'The simulated payment must succeed before confirmation.',
      );
    }

    final selectedProducts = products.where(
      (product) => (quantities[product.id] ?? 0) > 0,
    );

    if (selectedProducts.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    final grouped = <String, List<ProductModel>>{};

    for (final product in selectedProducts) {
      final quantity = quantities[product.id] ?? 0;

      if (quantity <= 0) {
        continue;
      }

      if (!product.isActive) {
        throw Exception('${product.name} is no longer available.');
      }

      if (product.stock <= 0) {
        throw Exception('${product.name} is out of stock.');
      }

      if (quantity > product.stock) {
        throw Exception(
          'Only ${product.stock} unit(s) of ${product.name} are available.',
        );
      }

      final sellerId = product.sellerId.trim();

      if (sellerId.isEmpty) {
        throw Exception('${product.name} has an invalid seller.');
      }

      grouped.putIfAbsent(sellerId, () => <ProductModel>[]);
      grouped[sellerId]!.add(product);
    }

    if (grouped.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    final batch = _firestore.batch();
    final orderIds = <String>[];

    for (final entry in grouped.entries) {
      final sellerProducts = entry.value;
      final firstProduct = sellerProducts.first;
      final orderReference = _orders.doc();

      final items = <Map<String, dynamic>>[];
      var subtotal = 0.0;

      for (final product in sellerProducts) {
        final quantity = quantities[product.id] ?? 0;
        final convertedUnitPrice = CurrencyService.convert(
          amount: product.price,
          from: product.currency,
          to: cleanCurrency,
        );

        items.add(
          OrderItemModel(
            productId: product.id,
            name: product.name,
            quantity: quantity,
            unitPrice: convertedUnitPrice,
            currency: cleanCurrency,
            imageUrl: product.imageUrl.trim(),
          ).toMap(),
        );

        subtotal += convertedUnitPrice * quantity;
      }

      final deliveryFee = cleanDeliveryOption == 'delivery'
          ? CurrencyService.deliveryFee(cleanCurrency)
          : 0.0;

      final total = subtotal + deliveryFee;

      batch.set(orderReference, {
        'clientId': client.uid,
        'clientName': client.name.trim(),
        'clientPhone': cleanPhone.isNotEmpty ? cleanPhone : client.phone.trim(),
        'sellerId': entry.key,
        'sellerName': firstProduct.sellerName.trim(),
        'sellerWhatsapp': firstProduct.sellerWhatsapp.trim(),
        'status': 'pending',
        'items': items,
        'totals': <String, double>{cleanCurrency: total},
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'total': total,
        'currency': cleanCurrency,
        'deliveryOption': cleanDeliveryOption,
        'deliveryLocation': cleanDeliveryOption == 'delivery'
            ? cleanLocation
            : '',
        'deliveryPhone': cleanPhone,
        'deliveryNotes': cleanNotes,
        'paymentMethod': cleanPaymentMethod,
        'paymentStatus': cleanPaymentStatus,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final notificationReference = _notifications.doc();

      final itemCount = items.fold<int>(
        0,
        (total, item) => total + ((item['quantity'] as num?)?.toInt() ?? 0),
      );

      batch.set(notificationReference, {
        'recipientId': entry.key,
        'senderId': client.uid,
        'type': 'new_order',
        'title': 'New paid order received',
        'message':
            '${client.name.trim()} placed a paid order for $itemCount item(s).',
        'orderId': orderReference.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      orderIds.add(orderReference.id);
    }

    batch.set(_cartDocument(client.uid), {
      'items': <String, dynamic>{},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    return orderIds;
  }

  Future<List<OrderModel>> getOrdersByIds(List<String> orderIds) async {
    final orders = <OrderModel>[];

    for (final orderId in orderIds) {
      final cleanId = orderId.trim();

      if (cleanId.isEmpty) {
        continue;
      }

      final snapshot = await _orders.doc(cleanId).get();

      if (snapshot.exists) {
        orders.add(OrderModel.fromDocument(snapshot));
      }
    }

    return orders;
  }

  Future<void> acceptOrder({
    required AppUser seller,
    required OrderModel order,
  }) async {
    _validateSeller(seller: seller, order: order);

    final orderReference = _orders.doc(order.id);

    await _firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderReference);

      final orderData = orderSnapshot.data();

      if (!orderSnapshot.exists || orderData == null) {
        throw Exception('Order no longer exists.');
      }

      if ((orderData['sellerId'] ?? '').toString() != seller.uid) {
        throw Exception('You cannot manage another seller order.');
      }

      if ((orderData['status'] ?? '').toString() != 'pending') {
        throw Exception('Only pending orders can be accepted.');
      }

      final rawItems = orderData['items'];

      if (rawItems is! List || rawItems.isEmpty) {
        throw Exception('This order has no valid items.');
      }

      final productUpdates = <DocumentReference<Map<String, dynamic>>, int>{};

      for (final rawItem in rawItems) {
        if (rawItem is! Map) {
          throw Exception('Invalid order item.');
        }

        final item = OrderItemModel.fromMap(Map<String, dynamic>.from(rawItem));

        if (item.productId.trim().isEmpty || item.quantity <= 0) {
          throw Exception('Invalid order item.');
        }

        final productReference = _products.doc(item.productId);

        final productSnapshot = await transaction.get(productReference);

        final productData = productSnapshot.data();

        if (!productSnapshot.exists || productData == null) {
          throw Exception('${item.name} no longer exists.');
        }

        if ((productData['sellerId'] ?? '').toString() != seller.uid) {
          throw Exception('${item.name} does not belong to this seller.');
        }

        final currentStock = _intFromValue(productData['stock']);

        if (currentStock < item.quantity) {
          throw Exception(
            'Not enough stock for ${item.name}. '
            'Available: $currentStock.',
          );
        }

        productUpdates[productReference] = currentStock - item.quantity;
      }

      for (final entry in productUpdates.entries) {
        transaction.update(entry.key, {
          'stock': entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.update(orderReference, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final notificationReference = _notifications.doc();

      transaction.set(notificationReference, {
        'recipientId': (orderData['clientId'] ?? '').toString(),
        'senderId': seller.uid,
        'type': 'order_accepted',
        'title': 'Order accepted',
        'message': '${seller.name.trim()} accepted your order.',
        'orderId': order.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelPendingOrder({
    required AppUser seller,
    required OrderModel order,
  }) async {
    _validateSeller(seller: seller, order: order);

    if (order.status != 'pending') {
      throw Exception('Only pending orders can be cancelled.');
    }

    final batch = _firestore.batch();
    final orderReference = _orders.doc(order.id);
    final notificationReference = _notifications.doc();

    batch.update(orderReference, {
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(notificationReference, {
      'recipientId': order.clientId,
      'senderId': seller.uid,
      'type': 'order_cancelled',
      'title': 'Order cancelled',
      'message': '${seller.name.trim()} cancelled your order.',
      'orderId': order.id,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> completeOrder({
    required AppUser seller,
    required OrderModel order,
  }) async {
    _validateSeller(seller: seller, order: order);

    if (order.status != 'accepted') {
      throw Exception('Only accepted orders can be completed.');
    }

    final batch = _firestore.batch();
    final orderReference = _orders.doc(order.id);
    final notificationReference = _notifications.doc();

    batch.update(orderReference, {
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(notificationReference, {
      'recipientId': order.clientId,
      'senderId': seller.uid,
      'type': 'order_completed',
      'title': 'Order completed',
      'message': '${seller.name.trim()} marked your order as completed.',
      'orderId': order.id,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  void _validateSeller({required AppUser seller, required OrderModel order}) {
    if (seller.role.trim().toLowerCase() != 'seller') {
      throw Exception('Only seller accounts can manage orders.');
    }

    if (seller.uid.trim().isEmpty || order.sellerId != seller.uid) {
      throw Exception('You cannot manage another seller order.');
    }
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

  int _intFromValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
