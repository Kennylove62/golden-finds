import 'package:flutter/material.dart';

import '../models/product_model.dart';

class ProductImageView extends StatelessWidget {
  const ProductImageView({
    super.key,
    required this.product,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final ProductModel product;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl.trim();
    final legacyBytes = product.imageBytes;

    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          if (legacyBytes != null) {
            return Image.memory(legacyBytes, fit: fit, gaplessPlayback: true);
          }

          return fallback;
        },
      );
    }

    if (legacyBytes != null) {
      return Image.memory(legacyBytes, fit: fit, gaplessPlayback: true);
    }

    return fallback;
  }
}
