import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.categoryId,
    required this.categoryName,
    required this.stock,
    required this.sellerId,
    required this.sellerName,
    required this.sellerWhatsapp,
    required this.isActive,
    this.imageBase64 = '',
    this.imageUrl = '',
    this.createdAt,
    this.updatedAt,
  });

  static const int _maxCachedImages = 40;

  static final Map<String, Uint8List> _decodedImageCache =
      <String, Uint8List>{};

  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String categoryId;
  final String categoryName;
  final int stock;
  final String imageBase64;
  final String imageUrl;
  final String sellerId;
  final String sellerName;
  final String sellerWhatsapp;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get inStock => stock > 0;

  bool get hasEmbeddedImage => imageBase64.trim().isNotEmpty;

  Uint8List? get imageBytes {
    final value = imageBase64.trim();

    if (value.isEmpty) {
      return null;
    }

    final cacheKey = '$id:${value.length}:${value.hashCode}';

    final cached = _decodedImageCache[cacheKey];

    if (cached != null) {
      return cached;
    }

    try {
      final decoded = base64Decode(value);

      if (_decodedImageCache.length >= _maxCachedImages) {
        final firstKey = _decodedImageCache.keys.first;
        _decodedImageCache.remove(firstKey);
      }

      _decodedImageCache[cacheKey] = decoded;

      return decoded;
    } catch (_) {
      return null;
    }
  }

  String get formattedPrice {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$${price.toStringAsFixed(2)}';
      case 'EUR':
        return '€${price.toStringAsFixed(2)}';
      case 'BIF':
      default:
        return '${price.toStringAsFixed(0)} BIF';
    }
  }

  factory ProductModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return ProductModel(
      id: document.id,
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      price: _doubleFromValue(data['price']),
      currency: (data['currency'] ?? 'BIF').toString(),
      categoryId: (data['categoryId'] ?? '').toString(),
      categoryName: (data['categoryName'] ?? '').toString(),
      stock: _intFromValue(data['stock']),
      imageBase64: (data['imageBase64'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      sellerId: (data['sellerId'] ?? '').toString(),
      sellerName: (data['sellerName'] ?? '').toString(),
      sellerWhatsapp: (data['sellerWhatsapp'] ?? '').toString(),
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
      createdAt: _dateFromValue(data['createdAt']),
      updatedAt: _dateFromValue(data['updatedAt']),
    );
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? currency,
    String? categoryId,
    String? categoryName,
    int? stock,
    String? imageBase64,
    String? imageUrl,
    String? sellerId,
    String? sellerName,
    String? sellerWhatsapp,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      stock: stock ?? this.stock,
      imageBase64: imageBase64 ?? this.imageBase64,
      imageUrl: imageUrl ?? this.imageUrl,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerWhatsapp: sellerWhatsapp ?? this.sellerWhatsapp,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
