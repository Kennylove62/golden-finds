import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import 'uploadcare_image_service.dart';

class CatalogService {
  CatalogService({
    FirebaseFirestore? firestore,
    UploadcareImageService? imageService,
  }) : _firestoreOverride = firestore,
       _imageService = imageService ?? UploadcareImageService();

  final FirebaseFirestore? _firestoreOverride;
  final UploadcareImageService _imageService;

  FirebaseFirestore get _firestore {
    return _firestoreOverride ?? FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>> get _categories {
    return _firestore.collection('categories');
  }

  CollectionReference<Map<String, dynamic>> get _products {
    return _firestore.collection('products');
  }

  Stream<List<CategoryModel>> watchCategories() {
    return _categories
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(CategoryModel.fromDocument).toList(),
        );
  }

  Future<List<CategoryModel>> getCategories() async {
    final snapshot = await _categories.orderBy('name').get();

    return snapshot.docs.map(CategoryModel.fromDocument).toList();
  }

  Stream<List<ProductModel>> watchPublicProducts() {
    return _products.where('isActive', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final products = snapshot.docs.map(ProductModel.fromDocument).toList();

      products.sort((a, b) => _compareDates(b.createdAt, a.createdAt));

      return products;
    });
  }

  Stream<List<ProductModel>> watchSellerProducts(String sellerId) {
    return _products.where('sellerId', isEqualTo: sellerId).snapshots().map((
      snapshot,
    ) {
      final products = snapshot.docs.map(ProductModel.fromDocument).toList();

      products.sort((a, b) => _compareDates(b.createdAt, a.createdAt));

      return products;
    });
  }

  Future<void> ensureDefaultCategories() async {
    const defaults = [
      ('fashion', 'Fashion'),
      ('shoes', 'Shoes'),
      ('accessories', 'Accessories'),
      ('beauty', 'Beauty'),
    ];

    for (final item in defaults) {
      final document = _categories.doc(item.$1);
      final snapshot = await document.get();

      if (!snapshot.exists) {
        await document.set({
          'name': item.$2,
          'slug': item.$1,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<String> createCategory({required String name}) async {
    final cleanName = name.trim();

    if (cleanName.length < 2) {
      throw Exception('Category name is too short.');
    }

    final slug = _slugify(cleanName);

    if (slug.isEmpty) {
      throw Exception('Category name is invalid.');
    }

    final existing = await _categories
        .where('slug', isEqualTo: slug)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final document = _categories.doc(slug);

    await document.set({
      'name': cleanName,
      'slug': slug,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  Future<String> createProduct({
    required AppUser seller,
    required String name,
    required String description,
    required double price,
    required String currency,
    required String categoryId,
    required String categoryName,
    required int stock,
    required String imageBase64,
    String imageUrl = '',
  }) async {
    _validateSeller(seller);

    _validateProduct(
      name: name,
      description: description,
      price: price,
      currency: currency,
      categoryId: categoryId,
      categoryName: categoryName,
      stock: stock,
      imageBase64: imageBase64,
      imageUrl: imageUrl,
    );

    final document = _products.doc();
    var storedImageUrl = imageUrl.trim();

    if (imageBase64.trim().isNotEmpty) {
      storedImageUrl = await _uploadProductImage(
        sellerId: seller.uid,
        productId: document.id,
        imageBase64: imageBase64,
      );
    }

    if (storedImageUrl.isEmpty) {
      throw Exception('The product image could not be uploaded to Uploadcare.');
    }

    await document.set({
      'name': name.trim(),
      'description': description.trim(),
      'price': price,
      'currency': currency.trim().toUpperCase(),
      'categoryId': categoryId.trim(),
      'categoryName': categoryName.trim(),
      'stock': stock,
      'imageBase64': '',
      'imageUrl': storedImageUrl,
      'sellerId': seller.uid,
      'sellerName': seller.name.trim(),
      'sellerWhatsapp': seller.whatsappNumber?.trim() ?? '',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  Future<void> updateProduct({
    required AppUser seller,
    required ProductModel product,
    required String name,
    required String description,
    required double price,
    required String currency,
    required String categoryId,
    required String categoryName,
    required int stock,
    required String imageBase64,
    required bool isActive,
  }) async {
    _validateSeller(seller);

    if (product.sellerId != seller.uid) {
      throw Exception('You cannot modify another seller product.');
    }

    _validateProduct(
      name: name,
      description: description,
      price: price,
      currency: currency,
      categoryId: categoryId,
      categoryName: categoryName,
      stock: stock,
      imageBase64: imageBase64,
      imageUrl: product.imageUrl,
    );

    var storedImageUrl = product.imageUrl.trim();

    if (imageBase64.trim().isNotEmpty) {
      storedImageUrl = await _uploadProductImage(
        sellerId: seller.uid,
        productId: product.id,
        imageBase64: imageBase64,
      );
    }

    if (storedImageUrl.isEmpty) {
      throw Exception('The product image could not be uploaded to Uploadcare.');
    }

    await _products.doc(product.id).update({
      'name': name.trim(),
      'description': description.trim(),
      'price': price,
      'currency': currency.trim().toUpperCase(),
      'categoryId': categoryId.trim(),
      'categoryName': categoryName.trim(),
      'stock': stock,
      'imageBase64': '',
      'imageUrl': storedImageUrl,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStock({
    required AppUser seller,
    required ProductModel product,
    required int stock,
  }) async {
    _validateSeller(seller);

    if (product.sellerId != seller.uid) {
      throw Exception('You cannot modify another seller stock.');
    }

    if (stock < 0) {
      throw Exception('Stock cannot be negative.');
    }

    await _products.doc(product.id).update({
      'stock': stock,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setProductActive({
    required AppUser seller,
    required ProductModel product,
    required bool active,
  }) async {
    _validateSeller(seller);

    if (product.sellerId != seller.uid) {
      throw Exception('You cannot modify another seller product.');
    }

    await _products.doc(product.id).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct({
    required AppUser seller,
    required ProductModel product,
  }) async {
    _validateSeller(seller);

    if (product.sellerId != seller.uid) {
      throw Exception('You cannot delete another seller product.');
    }

    await _products.doc(product.id).delete();

    // The public Uploadcare key is intentionally the only Uploadcare
    // credential shipped in the Flutter app. Remote file deletion requires
    // privileged credentials and is therefore not performed from the client.
  }

  Future<String> _uploadProductImage({
    required String sellerId,
    required String productId,
    required String imageBase64,
  }) {
    return _imageService.uploadProductImage(
      sellerId: sellerId,
      productId: productId,
      imageBase64: imageBase64,
    );
  }

  void _validateSeller(AppUser seller) {
    if (seller.role.trim().toLowerCase() != 'seller') {
      throw Exception('Only sellers can manage products.');
    }

    if (seller.uid.trim().isEmpty) {
      throw Exception('Seller account is invalid.');
    }
  }

  void _validateProduct({
    required String name,
    required String description,
    required double price,
    required String currency,
    required String categoryId,
    required String categoryName,
    required int stock,
    required String imageBase64,
    required String imageUrl,
  }) {
    if (name.trim().length < 2) {
      throw Exception('Product name is too short.');
    }

    if (description.trim().length < 5) {
      throw Exception('Product description is too short.');
    }

    if (price <= 0) {
      throw Exception('Product price must be greater than zero.');
    }

    final cleanCurrency = currency.trim().toUpperCase();

    if (!const {'BIF', 'USD', 'EUR'}.contains(cleanCurrency)) {
      throw Exception('Unsupported currency.');
    }

    if (categoryId.trim().isEmpty || categoryName.trim().isEmpty) {
      throw Exception('Select a product category.');
    }

    if (stock < 0) {
      throw Exception('Stock cannot be negative.');
    }

    if (imageBase64.trim().isEmpty && imageUrl.trim().isEmpty) {
      throw Exception('A product image is required.');
    }

    if (imageBase64.length > 600000) {
      throw Exception('The compressed image is still too large.');
    }
  }

  String _slugify(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
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
