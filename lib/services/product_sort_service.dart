import '../models/product_model.dart';
import 'currency_service.dart';

enum ProductSortOption {
  recommended,
  priceLowToHigh,
  priceHighToLow,
  nameAToZ,
  stockHighToLow,
}

extension ProductSortOptionLabel on ProductSortOption {
  String get label {
    switch (this) {
      case ProductSortOption.recommended:
        return 'Recommended';
      case ProductSortOption.priceLowToHigh:
        return 'Price: Low to High';
      case ProductSortOption.priceHighToLow:
        return 'Price: High to Low';
      case ProductSortOption.nameAToZ:
        return 'Name: A to Z';
      case ProductSortOption.stockHighToLow:
        return 'Stock: High to Low';
    }
  }
}

class ProductSortService {
  const ProductSortService._();

  static List<ProductModel> sort(
    List<ProductModel> products,
    ProductSortOption option, {
    bool inStockFirstForRecommended = true,
  }) {
    final result = List<ProductModel>.from(products);

    final originalOrder = <String, int>{
      for (var index = 0; index < result.length; index++)
        result[index].id: index,
    };

    int originalCompare(ProductModel a, ProductModel b) {
      final left = originalOrder[a.id] ?? 0;
      final right = originalOrder[b.id] ?? 0;
      return left.compareTo(right);
    }

    switch (option) {
      case ProductSortOption.recommended:
        if (!inStockFirstForRecommended) {
          return result;
        }

        result.sort((a, b) {
          if (a.inStock != b.inStock) {
            return a.inStock ? -1 : 1;
          }

          return originalCompare(a, b);
        });

        return result;

      case ProductSortOption.priceLowToHigh:
        result.sort((a, b) {
          final compared = _priceInBif(a).compareTo(_priceInBif(b));

          if (compared != 0) {
            return compared;
          }

          return originalCompare(a, b);
        });

        return result;

      case ProductSortOption.priceHighToLow:
        result.sort((a, b) {
          final compared = _priceInBif(b).compareTo(_priceInBif(a));

          if (compared != 0) {
            return compared;
          }

          return originalCompare(a, b);
        });

        return result;

      case ProductSortOption.nameAToZ:
        result.sort((a, b) {
          final compared = a.name.toLowerCase().compareTo(b.name.toLowerCase());

          if (compared != 0) {
            return compared;
          }

          return originalCompare(a, b);
        });

        return result;

      case ProductSortOption.stockHighToLow:
        result.sort((a, b) {
          final compared = b.stock.compareTo(a.stock);

          if (compared != 0) {
            return compared;
          }

          return originalCompare(a, b);
        });

        return result;
    }
  }

  static double _priceInBif(ProductModel product) {
    try {
      return CurrencyService.convert(
        amount: product.price,
        from: product.currency,
        to: 'BIF',
      );
    } catch (_) {
      return product.price;
    }
  }
}
