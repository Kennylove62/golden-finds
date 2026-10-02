import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItemModel {
  const OrderItemModel({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.currency,
    this.imageUrl = '',
  });

  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final String currency;
  final String imageUrl;

  double get lineTotal => unitPrice * quantity;

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      productId: (map['productId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      quantity: _intFromValue(map['quantity']),
      unitPrice: _doubleFromValue(map['unitPrice']),
      currency: (map['currency'] ?? 'BIF').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'currency': currency.toUpperCase(),
      'imageUrl': imageUrl.trim(),
    };
  }

  static double _doubleFromValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _intFromValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.sellerId,
    required this.sellerName,
    required this.sellerWhatsapp,
    required this.status,
    required this.items,
    required this.totals,
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.total = 0,
    this.currency = '',
    this.deliveryOption = '',
    this.deliveryLocation = '',
    this.deliveryPhone = '',
    this.deliveryNotes = '',
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String sellerId;
  final String sellerName;
  final String sellerWhatsapp;
  final String status;
  final List<OrderItemModel> items;

  // Kept for backward compatibility with orders created before the final
  // examination checkout flow. New orders use one selected currency.
  final Map<String, double> totals;

  final double subtotal;
  final double deliveryFee;
  final double total;
  final String currency;
  final String deliveryOption;
  final String deliveryLocation;
  final String deliveryPhone;
  final String deliveryNotes;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get totalQuantity {
    return items.fold(0, (total, item) => total + item.quantity);
  }

  bool get hasCheckoutDetails {
    return currency.trim().isNotEmpty &&
        deliveryOption.trim().isNotEmpty &&
        paymentStatus.trim().isNotEmpty;
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  String get deliveryOptionLabel {
    switch (deliveryOption.toLowerCase()) {
      case 'delivery':
        return 'Delivery';
      case 'pickup':
        return 'Physical boutique pickup';
      default:
        return 'Not specified';
    }
  }

  String get paymentMethodLabel {
    switch (paymentMethod.toLowerCase()) {
      case 'mobile_money':
        return 'Mobile Money';
      case 'bank_card':
        return 'Bank Card';
      default:
        return paymentMethod.trim().isEmpty ? 'Not specified' : paymentMethod;
    }
  }

  String get paymentStatusLabel {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'failed':
        return 'Failed';
      case 'pending':
        return 'Pending';
      default:
        return paymentStatus.trim().isEmpty ? 'Not specified' : paymentStatus;
    }
  }

  String get formattedSubtotal {
    if (currency.trim().isNotEmpty) {
      return formatMoney(subtotal, currency);
    }

    return formattedTotals;
  }

  String get formattedDeliveryFee {
    if (currency.trim().isEmpty) {
      return '0 BIF';
    }

    return formatMoney(deliveryFee, currency);
  }

  String get formattedTotal {
    if (currency.trim().isNotEmpty) {
      return formatMoney(total, currency);
    }

    return formattedTotals;
  }

  String get formattedTotals {
    if (currency.trim().isNotEmpty && (total > 0 || hasCheckoutDetails)) {
      return formatMoney(total, currency);
    }

    if (totals.isEmpty) {
      return '0 BIF';
    }

    final currencies = totals.keys.toList()..sort();

    return currencies
        .map((currency) => formatMoney(totals[currency] ?? 0, currency))
        .join(' • ');
  }

  String get createdAtLabel {
    final value = createdAt;

    if (value == null) {
      return 'Just now';
    }

    String two(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  factory OrderModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    final rawItems = data['items'];
    final items = <OrderItemModel>[];

    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is Map) {
          items.add(OrderItemModel.fromMap(Map<String, dynamic>.from(rawItem)));
        }
      }
    }

    final rawTotals = data['totals'];
    final totals = <String, double>{};

    if (rawTotals is Map) {
      for (final entry in rawTotals.entries) {
        final value = entry.value;

        totals[entry.key.toString()] = value is num
            ? value.toDouble()
            : double.tryParse(value.toString()) ?? 0;
      }
    }

    return OrderModel(
      id: document.id,
      clientId: (data['clientId'] ?? '').toString(),
      clientName: (data['clientName'] ?? '').toString(),
      clientPhone: (data['clientPhone'] ?? '').toString(),
      sellerId: (data['sellerId'] ?? '').toString(),
      sellerName: (data['sellerName'] ?? '').toString(),
      sellerWhatsapp: (data['sellerWhatsapp'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      items: items,
      totals: totals,
      subtotal: _doubleFromValue(data['subtotal']),
      deliveryFee: _doubleFromValue(data['deliveryFee']),
      total: _doubleFromValue(data['total']),
      currency: (data['currency'] ?? '').toString().toUpperCase(),
      deliveryOption: (data['deliveryOption'] ?? '').toString(),
      deliveryLocation: (data['deliveryLocation'] ?? '').toString(),
      deliveryPhone: (data['deliveryPhone'] ?? '').toString(),
      deliveryNotes: (data['deliveryNotes'] ?? '').toString(),
      paymentMethod: (data['paymentMethod'] ?? '').toString(),
      paymentStatus: (data['paymentStatus'] ?? '').toString(),
      createdAt: _dateFromValue(data['createdAt']),
      updatedAt: _dateFromValue(data['updatedAt']),
    );
  }

  static String formatMoney(double amount, String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${amount.toStringAsFixed(2)}';
      case 'BIF':
      default:
        return '${amount.toStringAsFixed(0)} BIF';
    }
  }

  static double _doubleFromValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
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
