import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/golden_dark.dart';

import '../../models/app_user.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../models/app_notification.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_service.dart';
import '../../services/cart_service.dart';
import '../../services/order_service.dart';
import '../../services/favorite_service.dart';
import '../../services/notification_service.dart';
import '../../services/whatsapp_service.dart';
import '../../widgets/product_image_view.dart';
import '../../services/product_sort_service.dart';
import '../shared/edit_profile_screen.dart';
import 'checkout_screen.dart';
import '../shared/notification_center_dialog.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  static const Color navy = Color(0xFF0B2638);
  static const Color deepNavy = Color(0xFF061923);
  static const Color teal = Color(0xFF17A99A);
  static const Color brightTeal = Color(0xFF69E1D5);
  static const Color ice = Color(0xFFF2F9FA);
  static const Color softTeal = Color(0xFFDDF7F3);

  int _selectedIndex = 0;

  final CatalogService _catalogService = CatalogService();
  final CartService _cartService = CartService();
  final OrderService _orderService = OrderService();
  final FavoriteService _favoriteService = FavoriteService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _shopSearchController = TextEditingController();

  late final Stream<List<ProductModel>> _productsStream;
  StreamSubscription<Map<String, int>>? _cartSubscription;
  StreamSubscription<Set<String>>? _favoriteSubscription;
  StreamSubscription<List<AppNotification>>? _notificationSubscription;

  final Set<String> _favoriteProductIds = <String>{};
  final Map<String, int> _cartQuantities = <String, int>{};

  // Cart writes are optimistic in the UI. Firestore can emit an older
  // snapshot while several + / - taps are being saved. Keep the latest
  // desired quantity per product and serialize writes so an old snapshot
  // can never make the visible counter jump backwards.
  final Map<String, int> _pendingCartQuantities = <String, int>{};
  final Map<String, Future<void>> _cartWriteQueues = <String, Future<void>>{};

  List<ProductModel> _latestProducts = const <ProductModel>[];
  List<AppNotification> _notifications = const <AppNotification>[];
  String _selectedShopCategory = 'All';
  ProductSortOption _shopSortOption = ProductSortOption.recommended;
  String _selectedOrderStatus = 'all';
  bool _checkoutInProgress = false;
  bool _catalogueLoaded = false;
  bool _reconciliationQueued = false;
  String _catalogueSignature = '';

  @override
  void initState() {
    super.initState();
    _productsStream = _createProductsStream();

    _cartSubscription = _createCartStream().listen(_applyRemoteCart);

    _favoriteSubscription = _createFavoriteStream().listen(
      _applyRemoteFavorites,
    );

    _notificationSubscription = _createNotificationStream().listen(
      _applyRemoteNotifications,
    );
  }

  Stream<List<ProductModel>> _createProductsStream() {
    try {
      return _catalogService.watchPublicProducts();
    } catch (_) {
      // Widget tests build the Client screen without Firebase.initializeApp().
      // In the real application Firebase is initialized in main.dart.
      return Stream<List<ProductModel>>.value(const <ProductModel>[]);
    }
  }

  void _rememberProducts(List<ProductModel> products) {
    _latestProducts = products;
    _catalogueLoaded = true;

    final parts =
        products
            .map(
              (product) =>
                  '${product.id}:${product.stock}:${product.isActive ? 1 : 0}',
            )
            .toList()
          ..sort();

    final signature = parts.join('|');

    if (signature == _catalogueSignature) {
      return;
    }

    _catalogueSignature = signature;
    _queueCatalogueReconciliation();
  }

  void _queueCatalogueReconciliation() {
    if (!_catalogueLoaded || _reconciliationQueued || !mounted) {
      return;
    }

    _reconciliationQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _reconciliationQueued = false;
        return;
      }

      _reconcileSavedState();
    });
  }

  Future<void> _reconcileSavedState() async {
    try {
      final productsById = <String, ProductModel>{
        for (final product in _latestProducts) product.id: product,
      };

      final nextCart = Map<String, int>.from(_cartQuantities);
      final nextFavorites = Set<String>.from(_favoriteProductIds);

      final cartUpdates = <String, int>{};
      final favoriteRemovals = <String>[];

      for (final entry in _cartQuantities.entries.toList()) {
        final product = productsById[entry.key];

        if (product == null || !product.isActive || product.stock <= 0) {
          nextCart.remove(entry.key);
          cartUpdates[entry.key] = 0;
          continue;
        }

        if (entry.value > product.stock) {
          nextCart[entry.key] = product.stock;
          cartUpdates[entry.key] = product.stock;
        }
      }

      for (final productId in _favoriteProductIds.toList()) {
        if (!productsById.containsKey(productId)) {
          nextFavorites.remove(productId);
          favoriteRemovals.add(productId);
        }
      }

      final cartChanged = !_sameCart(nextCart);
      final favoritesChanged = !_sameFavorites(nextFavorites);

      if (mounted && (cartChanged || favoritesChanged)) {
        setState(() {
          if (cartChanged) {
            _cartQuantities
              ..clear()
              ..addAll(nextCart);
          }

          if (favoritesChanged) {
            _favoriteProductIds
              ..clear()
              ..addAll(nextFavorites);
          }
        });
      }

      for (final entry in cartUpdates.entries) {
        try {
          await _cartService.setQuantity(
            userId: widget.user.uid,
            productId: entry.key,
            quantity: entry.value,
          );
        } catch (_) {
          // Keep the shopping UI responsive. A later catalogue/cart update
          // will retry reconciliation if the remote write could not complete.
        }
      }

      for (final productId in favoriteRemovals) {
        try {
          await _favoriteService.setFavorite(
            userId: widget.user.uid,
            productId: productId,
            favorite: false,
          );
        } catch (_) {
          // Same strategy as cart reconciliation: avoid blocking the UI.
        }
      }
    } finally {
      _reconciliationQueued = false;
    }
  }

  Stream<Map<String, int>> _createCartStream() {
    try {
      return _cartService.watchCart(widget.user.uid);
    } catch (_) {
      // Widget tests build this screen without Firebase.initializeApp().
      return const Stream<Map<String, int>>.empty();
    }
  }

  Stream<Set<String>> _createFavoriteStream() {
    try {
      return _favoriteService.watchFavorites(widget.user.uid);
    } catch (_) {
      // Widget tests build this screen without Firebase.initializeApp().
      return const Stream<Set<String>>.empty();
    }
  }

  Stream<List<AppNotification>> _createNotificationStream() {
    try {
      return _notificationService.watchNotifications(widget.user.uid);
    } catch (_) {
      return const Stream<List<AppNotification>>.empty();
    }
  }

  void _applyRemoteNotifications(List<AppNotification> notifications) {
    if (!mounted) {
      return;
    }

    setState(() {
      _notifications = notifications;
    });
  }

  int get _unreadNotificationCount {
    return _notifications.where((notification) => !notification.read).length;
  }

  Future<void> _showNotifications() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return NotificationCenterDialog(
          title: 'Notifications',
          notifications: _notifications,
          primaryColor: GoldenDark.clientInk(context),
          accentColor: GoldenDark.clientAccent(context),
          backgroundColor: GoldenDark.surface(context, light: ice),
          onMarkRead: (notification) async {
            await _notificationService.markRead(notification);
          },
          onMarkAllRead: () async {
            await _notificationService.markAllRead(widget.user.uid);
          },
          onOpenOrder: () {
            if (!mounted) {
              return;
            }

            _selectPage(3);
          },
        );
      },
    );
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: widget.user)),
    );

    if (!mounted || updated != true) {
      return;
    }

    _showMessage('Profile updated successfully.');
  }

  void _applyRemoteFavorites(Set<String> favorites) {
    if (!mounted || _sameFavorites(favorites)) {
      return;
    }

    setState(() {
      _favoriteProductIds
        ..clear()
        ..addAll(favorites);
    });

    _queueCatalogueReconciliation();
  }

  bool _sameFavorites(Set<String> favorites) {
    return favorites.length == _favoriteProductIds.length &&
        _favoriteProductIds.containsAll(favorites);
  }

  Future<void> _persistFavorite({
    required String productId,
    required bool favorite,
  }) async {
    try {
      await _favoriteService.setFavorite(
        userId: widget.user.uid,
        productId: productId,
        favorite: favorite,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Favorite sync failed: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  void _applyRemoteCart(Map<String, int> cart) {
    if (!mounted) {
      return;
    }

    // Start with Firestore's latest snapshot.
    final effectiveCart = Map<String, int>.from(cart);

    final confirmedProductIds = <String>[];

    // While a local quantity is still being persisted, an older Firestore
    // snapshot must not overwrite the optimistic counter shown to the user.
    for (final entry in _pendingCartQuantities.entries) {
      final remoteQuantity = cart[entry.key] ?? 0;
      final desiredQuantity = entry.value;

      if (remoteQuantity == desiredQuantity) {
        // Firestore has caught up with the latest local choice.
        confirmedProductIds.add(entry.key);
        continue;
      }

      // Keep showing the newest quantity selected by the user.
      if (desiredQuantity <= 0) {
        effectiveCart.remove(entry.key);
      } else {
        effectiveCart[entry.key] = desiredQuantity;
      }
    }

    for (final productId in confirmedProductIds) {
      _pendingCartQuantities.remove(productId);
    }

    if (_sameCart(effectiveCart)) {
      return;
    }

    setState(() {
      _cartQuantities
        ..clear()
        ..addAll(effectiveCart);
    });

    _queueCatalogueReconciliation();
  }

  bool _sameCart(Map<String, int> cart) {
    if (cart.length != _cartQuantities.length) {
      return false;
    }

    for (final entry in cart.entries) {
      if (_cartQuantities[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }

  Future<void> _persistCartQuantity(String productId, int quantity) {
    // Always remember the newest desired value immediately.
    _pendingCartQuantities[productId] = quantity;

    // Chain this write after the previous write for the SAME product.
    // This prevents responses from rapid taps (+ + + +) from arriving in
    // a different order and resetting the quantity to an older value.
    final previousQueue = _cartWriteQueues[productId] ?? Future<void>.value();

    late final Future<void> currentQueue;

    currentQueue = previousQueue
        .catchError((_) {
          // A previous failure must not block newer cart changes.
        })
        .then((_) async {
          await _cartService.setQuantity(
            userId: widget.user.uid,
            productId: productId,
            quantity: quantity,
          );
        })
        .catchError((error) {
          // Only clear the optimistic override if this failed write is still
          // the latest quantity requested for the product.
          if (_pendingCartQuantities[productId] == quantity) {
            _pendingCartQuantities.remove(productId);
          }

          if (!mounted) {
            return;
          }

          _showMessage(
            'Cart sync failed: ${error.toString().replaceFirst('Exception: ', '')}',
          );
        })
        .whenComplete(() {
          if (identical(_cartWriteQueues[productId], currentQueue)) {
            _cartWriteQueues.remove(productId);
          }
        });

    _cartWriteQueues[productId] = currentQueue;

    return currentQueue;
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    _favoriteSubscription?.cancel();
    _notificationSubscription?.cancel();
    _pendingCartQuantities.clear();
    _cartWriteQueues.clear();
    _shopSearchController.dispose();
    super.dispose();
  }

  int get _cartCount {
    return _cartQuantities.values.fold(
      0,
      (total, quantity) => total + quantity,
    );
  }

  List<String> _categoriesFromProducts(List<ProductModel> products) {
    final categories =
        products
            .map((product) => product.categoryName.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return ['All', ...categories];
  }

  List<ProductModel> _filterProducts(List<ProductModel> products) {
    final search = _shopSearchController.text.trim().toLowerCase();

    final filtered = products.where((product) {
      final matchesCategory =
          _selectedShopCategory == 'All' ||
          product.categoryName == _selectedShopCategory;

      final matchesSearch =
          search.isEmpty ||
          product.name.toLowerCase().contains(search) ||
          product.description.toLowerCase().contains(search) ||
          product.categoryName.toLowerCase().contains(search) ||
          product.sellerName.toLowerCase().contains(search);

      return matchesCategory && matchesSearch;
    }).toList();

    return ProductSortService.sort(
      filtered,
      _shopSortOption,
      inStockFirstForRecommended: true,
    );
  }

  void _toggleFavorite(ProductModel product) {
    final wasFavorite = _favoriteProductIds.contains(product.id);

    final nextFavorite = !wasFavorite;

    setState(() {
      if (nextFavorite) {
        _favoriteProductIds.add(product.id);
      } else {
        _favoriteProductIds.remove(product.id);
      }
    });

    _persistFavorite(productId: product.id, favorite: nextFavorite);

    _showMessage(
      nextFavorite
          ? '${product.name} added to favorites.'
          : '${product.name} removed from favorites.',
    );
  }

  void _addToCart(ProductModel product) {
    if (!product.inStock) {
      _showMessage('${product.name} is out of stock.');
      return;
    }

    final current = _cartQuantities[product.id] ?? 0;

    if (current >= product.stock) {
      _showMessage('You already selected the maximum available stock.');
      return;
    }

    final nextQuantity = current + 1;

    setState(() {
      _cartQuantities[product.id] = nextQuantity;
    });

    _persistCartQuantity(product.id, nextQuantity);

    _showMessage('${product.name} added to your cart.');
  }

  void _decreaseCart(ProductModel product) {
    final current = _cartQuantities[product.id] ?? 0;

    if (current <= 1) {
      setState(() {
        _cartQuantities.remove(product.id);
      });

      _persistCartQuantity(product.id, 0);
      return;
    }

    final nextQuantity = current - 1;

    setState(() {
      _cartQuantities[product.id] = nextQuantity;
    });

    _persistCartQuantity(product.id, nextQuantity);
  }

  void _removeFromCart(ProductModel product) {
    if (!_cartQuantities.containsKey(product.id)) {
      return;
    }

    setState(() {
      _cartQuantities.remove(product.id);
    });

    _persistCartQuantity(product.id, 0);

    _showMessage('${product.name} removed from your cart.');
  }

  void _showFavorites() {
    final favorites = _latestProducts
        .where((product) => _favoriteProductIds.contains(product.id))
        .toList();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: GoldenDark.surface(context, light: ice),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Row(
            children: [
              Icon(Icons.favorite_rounded, color: teal),
              SizedBox(width: 10),
              Text(
                'My Favorites',
                style: TextStyle(
                  color: GoldenDark.clientInk(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: favorites.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'You have not saved any products yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: GoldenDark.muted(context)),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: favorites.length,
                    separatorBuilder: (context, index) => Divider(),
                    itemBuilder: (context, index) {
                      final product = favorites[index];

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 54,
                            height: 54,
                            child: ProductImageView(
                              product: product,
                              fit: BoxFit.cover,
                              fallback: ColoredBox(
                                color: GoldenDark.clientSoft(
                                  context,
                                  light: softTeal,
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: GoldenDark.clientAccent(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: TextStyle(
                            color: GoldenDark.clientInk(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(product.formattedPrice),
                        trailing: IconButton(
                          tooltip: 'Remove favorite',
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _toggleFavorite(product);
                            _showFavorites();
                          },
                          icon: Icon(Icons.favorite_rounded, color: teal),
                        ),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _openProduct(product);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Map<String, double> _cartTotals(List<ProductModel> products) {
    final totals = <String, double>{};

    for (final product in products) {
      final quantity = _cartQuantities[product.id] ?? 0;

      if (quantity <= 0) {
        continue;
      }

      final currency = product.currency.trim().toUpperCase();

      totals[currency] = (totals[currency] ?? 0) + (product.price * quantity);
    }

    return totals;
  }

  String _formatTotals(Map<String, double> totals) {
    if (totals.isEmpty) {
      return '0 BIF';
    }

    final currencies = totals.keys.toList()..sort();

    return currencies
        .map(
          (currency) => OrderModel.formatMoney(totals[currency] ?? 0, currency),
        )
        .join(' • ');
  }

  Future<void> _confirmCheckout(List<ProductModel> products) async {
    if (_checkoutInProgress) {
      return;
    }

    if (_cartQuantities.isEmpty) {
      _showMessage('Your cart is empty.');
      return;
    }

    setState(() {
      _checkoutInProgress = true;
    });

    try {
      if (_cartWriteQueues.isNotEmpty) {
        await Future.wait(_cartWriteQueues.values.toList());
      }

      if (!mounted) {
        return;
      }

      final completed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            client: widget.user,
            products: List<ProductModel>.from(products),
            quantities: Map<String, int>.from(_cartQuantities),
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      if (completed == true) {
        setState(() {
          _cartQuantities.clear();
          _pendingCartQuantities.clear();
          _selectedIndex = 3;
        });

        _showMessage('Order checkout completed successfully.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkoutInProgress = false;
        });
      }
    }
  }

  void _showCart() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentProducts = _latestProducts
                .where((product) => (_cartQuantities[product.id] ?? 0) > 0)
                .toList();

            final totals = _cartTotals(currentProducts);

            final sellerCount = currentProducts
                .map((product) => product.sellerId)
                .where((sellerId) => sellerId.trim().isNotEmpty)
                .toSet()
                .length;

            Widget buildCartItem(ProductModel product, int quantity) {
              final lineSubtotal = OrderModel.formatMoney(
                product.price * quantity,
                product.currency,
              );

              final maxReached = quantity >= product.stock;

              Widget quantityControls() {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: GoldenDark.clientSoft(context, light: softTeal),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Decrease quantity',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _decreaseCart(product);
                          setDialogState(() {});
                        },
                        icon: Icon(
                          Icons.remove_rounded,
                          color: GoldenDark.clientInk(context),
                          size: 18,
                        ),
                      ),
                      Container(
                        constraints: BoxConstraints(minWidth: 32),
                        alignment: Alignment.center,
                        child: Text(
                          '$quantity',
                          style: TextStyle(
                            color: GoldenDark.clientInk(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: maxReached
                            ? 'Maximum stock selected'
                            : 'Increase quantity',
                        visualDensity: VisualDensity.compact,
                        onPressed: maxReached
                            ? null
                            : () {
                                _addToCart(product);
                                setDialogState(() {});
                              },
                        icon: Icon(
                          Icons.add_rounded,
                          color: GoldenDark.clientInk(context),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                );
              }

              Widget productInformation() {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: GoldenDark.clientInk(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: product.inStock
                                ? GoldenDark.clientSoft(
                                    context,
                                    light: softTeal,
                                  )
                                : (GoldenDark.enabled(context)
                                      ? const Color(0xFF4B252A)
                                      : const Color(0xFFFFE7E7)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product.inStock
                                ? '${product.stock} in stock'
                                : 'Out of stock',
                            style: TextStyle(
                              color: product.inStock ? teal : Colors.redAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Text(
                      product.sellerName.trim().isEmpty
                          ? 'Golden Finds seller'
                          : product.sellerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: GoldenDark.muted(context),
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      children: [
                        _ProductDetailChip(
                          icon: Icons.sell_outlined,
                          text: 'Unit ${product.formattedPrice}',
                        ),
                        _ProductDetailChip(
                          icon: Icons.category_outlined,
                          text: product.categoryName,
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GoldenDark.surface(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: navy.withValues(alpha: 0.07)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;

                    final imageWidget = ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: compact ? 72 : 88,
                        height: compact ? 72 : 88,
                        child: ProductImageView(
                          product: product,
                          fit: BoxFit.cover,
                          fallback: ColoredBox(
                            color: GoldenDark.clientSoft(
                              context,
                              light: softTeal,
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: GoldenDark.clientAccent(context),
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    );

                    final priceBlock = Column(
                      crossAxisAlignment: compact
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Subtotal',
                          style: TextStyle(
                            color: GoldenDark.subtle(context),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          lineSubtotal,
                          style: TextStyle(
                            color: GoldenDark.clientAccent(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    );

                    final removeButton = IconButton(
                      tooltip: 'Remove product',
                      onPressed: () {
                        _removeFromCart(product);
                        setDialogState(() {});
                      },
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                      ),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              imageWidget,
                              SizedBox(width: 12),
                              Expanded(child: productInformation()),
                            ],
                          ),
                          SizedBox(height: 14),
                          Row(
                            children: [
                              quantityControls(),
                              Spacer(),
                              priceBlock,
                              removeButton,
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        imageWidget,
                        SizedBox(width: 14),
                        Expanded(child: productInformation()),
                        SizedBox(width: 14),
                        quantityControls(),
                        SizedBox(width: 18),
                        priceBlock,
                        SizedBox(width: 4),
                        removeButton,
                      ],
                    );
                  },
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 860,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.86,
                ),
                decoration: BoxDecoration(
                  color: GoldenDark.surfaceAlt(context, light: ice),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withValues(alpha: 0.20),
                      blurRadius: 38,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 18, 18),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: GoldenDark.clientSoft(
                                context,
                                light: softTeal,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.shopping_cart_rounded,
                              color: GoldenDark.clientAccent(context),
                            ),
                          ),
                          SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'My Cart',
                                  style: TextStyle(
                                    color: GoldenDark.clientInk(context),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  currentProducts.isEmpty
                                      ? 'Your cart is ready for something new.'
                                      : '$_cartCount item${_cartCount == 1 ? '' : 's'} from $sellerCount seller${sellerCount == 1 ? '' : 's'}.',
                                  style: TextStyle(
                                    color: GoldenDark.muted(context),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close cart',
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            icon: Icon(Icons.close_rounded, color: navy),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: navy.withValues(alpha: 0.08)),
                    if (currentProducts.isEmpty)
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 58,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                color: GoldenDark.clientAccent(context),
                                size: 50,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Your cart is empty',
                                style: TextStyle(
                                  color: GoldenDark.clientInk(context),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 7),
                              Text(
                                'Explore the catalogue and add products you would like to buy.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: GoldenDark.muted(context),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                          itemCount: currentProducts.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 11),
                          itemBuilder: (context, index) {
                            final product = currentProducts[index];

                            final quantity = _cartQuantities[product.id] ?? 0;

                            return buildCartItem(product, quantity);
                          },
                        ),
                      ),
                    if (currentProducts.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                        decoration: BoxDecoration(
                          color: GoldenDark.surface(context),
                          border: Border(
                            top: BorderSide(
                              color: navy.withValues(alpha: 0.07),
                            ),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 620;

                            final summary = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cart total',
                                  style: TextStyle(
                                    color: GoldenDark.muted(context),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _formatTotals(totals),
                                  style: TextStyle(
                                    color: GoldenDark.clientInk(context),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  sellerCount > 1
                                      ? 'Checkout will create one order per seller.'
                                      : 'Stock is checked again when the seller accepts your order.',
                                  style: TextStyle(
                                    color: GoldenDark.subtle(context),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            );

                            final checkoutButton = FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: navy,
                                foregroundColor: Colors.white,
                                minimumSize: Size(
                                  compact ? double.infinity : 180,
                                  52,
                                ),
                              ),
                              onPressed: _checkoutInProgress
                                  ? null
                                  : () {
                                      Navigator.pop(dialogContext);

                                      _confirmCheckout(currentProducts);
                                    },
                              icon: Icon(Icons.lock_outline_rounded),
                              label: Text('Checkout'),
                            );

                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  summary,
                                  SizedBox(height: 14),
                                  checkoutButton,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: summary),
                                SizedBox(width: 22),
                                checkoutButton,
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openProduct(ProductModel product) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            constraints: BoxConstraints(maxWidth: 620),
            decoration: BoxDecoration(
              color: GoldenDark.surfaceAlt(context, light: ice),
              borderRadius: BorderRadius.circular(30),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: ProductImageView(
                      product: product,
                      fit: BoxFit.cover,
                      fallback: ColoredBox(
                        color: GoldenDark.clientSoft(context, light: softTeal),
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: GoldenDark.clientAccent(context),
                          size: 62,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: TextStyle(
                                  color: GoldenDark.clientInk(context),
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: _favoriteProductIds.contains(product.id)
                                  ? 'Remove favorite'
                                  : 'Add favorite',
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _toggleFavorite(product);
                                _openProduct(product);
                              },
                              icon: Icon(
                                _favoriteProductIds.contains(product.id)
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: GoldenDark.clientAccent(context),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 7),
                        Text(
                          product.formattedPrice,
                          style: TextStyle(
                            color: GoldenDark.clientAccent(context),
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 17),
                        Text(
                          product.description,
                          style: TextStyle(
                            color: GoldenDark.muted(context),
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 18),
                        Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: [
                            _ProductDetailChip(
                              icon: Icons.category_outlined,
                              text: product.categoryName,
                            ),
                            _ProductDetailChip(
                              icon: Icons.inventory_2_outlined,
                              text: product.inStock
                                  ? '${product.stock} in stock'
                                  : 'Out of stock',
                            ),
                            _ProductDetailChip(
                              icon: Icons.storefront_outlined,
                              text: product.sellerName,
                            ),
                          ],
                        ),
                        if (product.sellerWhatsapp.trim().isNotEmpty) ...[
                          SizedBox(height: 14),
                          Text(
                            'Seller WhatsApp: ${product.sellerWhatsapp}',
                            style: TextStyle(
                              color: GoldenDark.muted(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                },
                                child: Text('Close'),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: navy,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 54),
                                ),
                                onPressed: product.inStock
                                    ? () {
                                        Navigator.pop(dialogContext);
                                        _addToCart(product);
                                      }
                                    : null,
                                icon: Icon(Icons.add_shopping_cart_rounded),
                                label: Text(
                                  product.inStock
                                      ? 'Add to cart'
                                      : 'Out of stock',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get firstName {
    final name = widget.user.name.trim();

    if (name.isEmpty) {
      return 'Client';
    }

    return name.split(RegExp(r'\s+')).first;
  }

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: Text(
            'Sign out?',
            style: TextStyle(
              color: GoldenDark.clientInk(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Do you want to leave your Golden Finds client account?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Sign out',
                style: TextStyle(
                  color: GoldenDark.clientAccent(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await AuthService().logout();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 900;

    return Scaffold(
      backgroundColor: GoldenDark.page(context, light: ice),
      body: SafeArea(
        child: desktop
            ? Row(
                children: [
                  _ClientSideNavigation(
                    selectedIndex: _selectedIndex,
                    firstName: firstName,
                    onSelected: _selectPage,
                    onLogout: _logout,
                    onFavorites: _showFavorites,
                  ),
                  Expanded(child: _currentPage()),
                ],
              )
            : _currentPage(),
      ),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              backgroundColor: GoldenDark.surface(context),
              indicatorColor: teal.withValues(alpha: 0.16),
              onDestinationSelected: _selectPage,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront_rounded),
                  label: 'Shop',
                ),
                NavigationDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category_rounded),
                  label: 'Categories',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Orders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }

  Widget _currentPage() {
    switch (_selectedIndex) {
      case 1:
        return _shopPage();

      case 2:
        return _categoriesPage();

      case 3:
        return _ordersPage();

      case 4:
        return _profilePage();

      default:
        return _dashboardPage();
    }
  }

  Widget _dashboardPage() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _ClientHeader(
            firstName: firstName,
            onNotifications: _showNotifications,
            onFavorites: _showFavorites,
            onCart: _showCart,
            cartCount: _cartCount,
            notificationCount: _unreadNotificationCount,
            onProfile: () {
              _selectPage(4);
            },
          ),
        ),
        SliverToBoxAdapter(child: _heroSection()),
        SliverToBoxAdapter(
          child: _SectionTitle(
            title: 'Quick access',
            subtitle: 'Everything you need in your private shopping space.',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          sliver: SliverGrid(
            delegate: SliverChildListDelegate([
              _ClientQuickAction(
                icon: Icons.favorite_border_rounded,
                title: 'Favorites',
                subtitle: 'Products you saved',
                onTap: _showFavorites,
              ),
              _ClientQuickAction(
                icon: Icons.shopping_cart_outlined,
                title: 'My cart',
                subtitle: 'Prepare your purchase',
                onTap: _showCart,
              ),
              _ClientQuickAction(
                icon: Icons.category_outlined,
                title: 'Categories',
                subtitle: 'Browse by product type',
                onTap: () {
                  _selectPage(2);
                },
              ),
              _ClientQuickAction(
                icon: Icons.receipt_long_outlined,
                title: 'Orders',
                subtitle: 'Track your purchases',
                onTap: () {
                  _selectPage(3);
                },
              ),
            ]),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 118,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
          ),
        ),
        SliverToBoxAdapter(child: _recommendedProductsSection()),
      ],
    );
  }

  Widget _recommendedProductsSection() {
    return StreamBuilder<List<ProductModel>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <ProductModel>[];

        if (snapshot.hasData) {
          _rememberProducts(products);
        }

        final recommended = products
            .where((product) => product.inStock)
            .take(6)
            .toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recommended for you',
                      style: TextStyle(
                        color: GoldenDark.clientInk(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _selectPage(1);
                    },
                    child: Text(
                      'See all',
                      style: TextStyle(
                        color: GoldenDark.clientAccent(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.data == null)
                Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator(color: teal)),
                )
              else if (snapshot.hasError)
                _ClientCatalogueMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load products',
                  text: snapshot.error.toString(),
                )
              else if (recommended.isEmpty)
                const _ClientCatalogueMessage(
                  icon: Icons.inventory_2_outlined,
                  title: 'No in-stock products right now',
                  text:
                      'You can still browse the shop and check products that are temporarily out of stock.',
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recommended.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 285,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemBuilder: (context, index) {
                    final product = recommended[index];

                    return _ClientProductCard(
                      product: product,
                      favorite: _favoriteProductIds.contains(product.id),
                      onFavorite: () {
                        _toggleFavorite(product);
                      },
                      onTap: () {
                        _openProduct(product);
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 4, 24, 30),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navy, deepNavy],
        ),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.22),
            blurRadius: 34,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -45,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [teal.withValues(alpha: 0.28), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: -20,
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 160,
              color: teal.withValues(alpha: 0.10),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 580;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: teal.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: brightTeal.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Text(
                      'SIGNED IN • CLIENT',
                      style: TextStyle(
                        color: brightTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.7,
                      ),
                    ),
                  ),
                  SizedBox(height: 22),
                  Text(
                    compact
                        ? 'Your marketplace,\nyour way.'
                        : 'Your marketplace,\nyour way.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 31 : 38,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 470),
                    child: Text(
                      'Discover products from trusted sellers, save your favorites, build your cart and follow every order from one private space.',
                      style: TextStyle(color: Colors.white60, height: 1.5),
                    ),
                  ),
                  SizedBox(height: 26),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _PremiumButton(
                        label: 'Start shopping',
                        icon: Icons.storefront_outlined,
                        backgroundColor: teal,
                        foregroundColor: Colors.white,
                        width: 174,
                        onTap: () {
                          _selectPage(1);
                        },
                      ),
                      _PremiumButton(
                        label: 'My orders',
                        icon: Icons.receipt_long_outlined,
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        borderColor: Colors.white24,
                        width: 150,
                        onTap: () {
                          _selectPage(3);
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _shopPage() {
    return StreamBuilder<List<ProductModel>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <ProductModel>[];

        if (snapshot.hasData) {
          _rememberProducts(products);
        }

        final categories = _categoriesFromProducts(products);

        if (!categories.contains(_selectedShopCategory)) {
          _selectedShopCategory = 'All';
        }

        final visibleProducts = _filterProducts(products);

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _PageHeader(
                icon: Icons.storefront_outlined,
                title: 'Golden Shop',
                subtitle:
                    'Discover real products published by Golden Finds sellers.',
                actionIcon: Icons.shopping_cart_outlined,
                actionLabel: 'Cart ($_cartCount)',
                onAction: _showCart,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: TextField(
                  controller: _shopSearchController,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products, categories or sellers...',
                    prefixIcon: Icon(Icons.search_rounded),
                    suffixIcon: _shopSearchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _shopSearchController.clear();
                              setState(() {});
                            },
                            icon: Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final category = categories[index];

                    return _ShopFilterChip(
                      label: category,
                      selected: _selectedShopCategory == category,
                      onTap: () {
                        setState(() {
                          _selectedShopCategory = category;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _ClientSortButton(
                    value: _shopSortOption,
                    onSelected: (value) {
                      setState(() {
                        _shopSortOption = value;
                      });
                    },
                  ),
                ),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: teal)),
              )
            else if (snapshot.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ClientCatalogueMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load shop',
                  text: snapshot.error.toString(),
                ),
              )
            else if (visibleProducts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyClientState(
                  icon: Icons.search_off_rounded,
                  title: 'No products found',
                  text: 'Try another search or category.',
                  buttonText: 'Show all',
                  onPressed: () {
                    _shopSearchController.clear();
                    setState(() {
                      _selectedShopCategory = 'All';
                    });
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 110),
                sliver: SliverGrid.builder(
                  itemCount: visibleProducts.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 295,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemBuilder: (context, index) {
                    final product = visibleProducts[index];

                    return _ClientProductCard(
                      product: product,
                      favorite: _favoriteProductIds.contains(product.id),
                      onFavorite: () {
                        _toggleFavorite(product);
                      },
                      onTap: () {
                        _openProduct(product);
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _categoriesPage() {
    return StreamBuilder<List<ProductModel>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <ProductModel>[];

        if (snapshot.hasData) {
          _rememberProducts(products);
        }

        final categories = _categoriesFromProducts(
          products,
        ).where((category) => category != 'All').toList();

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _PageHeader(
                icon: Icons.category_outlined,
                title: 'Categories',
                subtitle:
                    'Find products faster by browsing the live marketplace categories.',
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: teal)),
              )
            else if (snapshot.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ClientCatalogueMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load categories',
                  text: snapshot.error.toString(),
                ),
              )
            else if (categories.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _ClientCatalogueMessage(
                  icon: Icons.category_outlined,
                  title: 'No categories yet',
                  text: 'Categories will appear when sellers publish products.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 110),
                sliver: SliverGrid.builder(
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 390,
                    mainAxisExtent: 165,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final count = products
                        .where((product) => product.categoryName == category)
                        .length;

                    return _ClientCategoryCard(
                      title: category,
                      subtitle: '$count product${count == 1 ? '' : 's'}',
                      icon: _categoryIcon(category),
                      onTap: () {
                        setState(() {
                          _selectedShopCategory = category;
                          _selectedIndex = 1;
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _ordersPage() {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.watchClientOrders(widget.user.uid),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const <OrderModel>[];

        final visibleOrders = _selectedOrderStatus == 'all'
            ? orders
            : orders
                  .where((order) => order.status == _selectedOrderStatus)
                  .toList();

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _PageHeader(
                icon: Icons.receipt_long_outlined,
                title: 'My Orders',
                subtitle:
                    'Track every real order placed with your Golden Finds account.',
                actionIcon: Icons.refresh_rounded,
                actionLabel: 'Live',
                onAction: () {
                  _showMessage('Orders update automatically.');
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    for (final status in const [
                      'all',
                      'pending',
                      'accepted',
                      'completed',
                      'cancelled',
                    ])
                      _InteractiveOrderStatusChip(
                        text: status == 'all'
                            ? 'All'
                            : status[0].toUpperCase() + status.substring(1),
                        selected: _selectedOrderStatus == status,
                        onTap: () {
                          setState(() {
                            _selectedOrderStatus = status;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: teal)),
              )
            else if (snapshot.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ClientCatalogueMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load orders',
                  text: snapshot.error.toString(),
                ),
              )
            else if (visibleOrders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyClientState(
                  icon: Icons.shopping_bag_outlined,
                  title: orders.isEmpty
                      ? 'No orders yet'
                      : 'No matching orders',
                  text: orders.isEmpty
                      ? 'Checkout your cart and your real order history will appear here.'
                      : 'There are no orders with this status.',
                  buttonText: 'Explore products',
                  onPressed: () {
                    _selectPage(1);
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                sliver: SliverList.separated(
                  itemCount: visibleOrders.length,
                  separatorBuilder: (context, index) => SizedBox(height: 13),
                  itemBuilder: (context, index) {
                    return _ClientOrderCard(
                      order: visibleOrders[index],
                      products: _latestProducts,
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _profilePage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 110),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(34),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [navy, deepNavy],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withValues(alpha: 0.18),
                      blurRadius: 30,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: GoldenDark.clientAccent(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: brightTeal, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: teal.withValues(alpha: 0.30),
                            blurRadius: 28,
                          ),
                        ],
                      ),
                      child: Text(
                        firstName[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(height: 19),
                    Text(
                      widget.user.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      widget.user.email,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                    SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: teal.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: brightTeal.withValues(alpha: 0.50),
                        ),
                      ),
                      child: Text(
                        'CLIENT ACCOUNT',
                        style: TextStyle(
                          color: brightTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 26),
              _ClientProfileInfo(
                icon: Icons.person_outline_rounded,
                label: 'Full name',
                value: widget.user.name,
              ),
              SizedBox(height: 12),
              _ClientProfileInfo(
                icon: Icons.email_outlined,
                label: 'Email address',
                value: widget.user.email,
              ),
              SizedBox(height: 12),
              _ClientProfileInfo(
                icon: Icons.phone_outlined,
                label: 'Phone number',
                value: widget.user.phone.trim().isEmpty
                    ? 'Not provided'
                    : widget.user.phone,
              ),
              SizedBox(height: 26),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;

                  if (compact) {
                    return Column(
                      children: [
                        _PremiumButton(
                          label: 'Edit profile',
                          icon: Icons.edit_outlined,
                          backgroundColor: GoldenDark.surface(context),
                          foregroundColor: GoldenDark.clientInk(context),
                          borderColor: teal.withValues(alpha: 0.25),
                          width: double.infinity,
                          onTap: _openEditProfile,
                        ),
                        SizedBox(height: 12),
                        _PremiumButton(
                          label: 'Sign out',
                          icon: Icons.logout_rounded,
                          backgroundColor: navy,
                          foregroundColor: Colors.white,
                          width: double.infinity,
                          onTap: _logout,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: _PremiumButton(
                          label: 'Edit profile',
                          icon: Icons.edit_outlined,
                          backgroundColor: GoldenDark.surface(context),
                          foregroundColor: GoldenDark.clientInk(context),
                          borderColor: teal.withValues(alpha: 0.25),
                          onTap: _openEditProfile,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _PremiumButton(
                          label: 'Sign out',
                          icon: Icons.logout_rounded,
                          backgroundColor: navy,
                          foregroundColor: Colors.white,
                          onTap: _logout,
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: GoldenDark.clientSoft(context, light: softTeal),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: teal),
                    SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        'Your Golden Finds client session is active and connected.',
                        style: TextStyle(
                          color: GoldenDark.clientInk(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Fashion':
        return Icons.checkroom_outlined;

      case 'Shoes':
        return Icons.directions_run_outlined;

      case 'Accessories':
        return Icons.watch_outlined;

      case 'Beauty':
        return Icons.spa_outlined;

      default:
        return Icons.category_outlined;
    }
  }
}

class _ClientHeader extends StatelessWidget {
  const _ClientHeader({
    required this.firstName,
    required this.onNotifications,
    required this.onFavorites,
    required this.onCart,
    required this.onProfile,
    required this.cartCount,
    required this.notificationCount,
  });

  final String firstName;
  final VoidCallback onNotifications;
  final VoidCallback onFavorites;
  final VoidCallback onCart;
  final VoidCallback onProfile;
  final int cartCount;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF17A99A);

    Widget identity({required bool compact}) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onProfile,
            child: Container(
              width: compact ? 50 : 54,
              height: compact ? 50 : 54,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: teal,
                shape: BoxShape.circle,
              ),
              child: Text(
                firstName.isEmpty ? 'C' : firstName[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLIENT SPACE',
                  style: TextStyle(
                    color: GoldenDark.clientAccent(context),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hello, $firstName',
                  maxLines: compact ? 2 : 1,
                  softWrap: compact,
                  overflow: compact
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: GoldenDark.clientInk(context),
                    fontSize: compact ? 20 : 24,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget notificationButton() {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          _HeaderIcon(
            tooltip: 'Notifications',
            icon: Icons.notifications_none_rounded,
            onTap: onNotifications,
          ),
          if (notificationCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: teal,
                child: Text(
                  notificationCount > 9 ? '9+' : '$notificationCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    Widget cartButton() {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          _HeaderIcon(
            tooltip: 'Cart',
            icon: Icons.shopping_cart_outlined,
            onTap: onCart,
          ),
          if (cartCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: teal,
                child: Text(
                  cartCount > 9 ? '9+' : '$cartCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    Widget actions() {
      return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _HeaderIcon(
            tooltip: 'Favorites',
            icon: Icons.favorite_border_rounded,
            onTap: onFavorites,
          ),
          notificationButton(),
          cartButton(),
          _HeaderIcon(
            tooltip: 'Profile',
            icon: Icons.account_circle_outlined,
            onTap: onProfile,
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 24,
            18,
            compact ? 16 : 24,
            14,
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity(compact: true),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerRight, child: actions()),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: identity(compact: false)),
                    const SizedBox(width: 12),
                    actions(),
                  ],
                ),
        );
      },
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: const Color(0xFF0B2638)),
    );
  }
}

class _ClientSideNavigation extends StatelessWidget {
  const _ClientSideNavigation({
    required this.selectedIndex,
    required this.firstName,
    required this.onSelected,
    required this.onLogout,
    required this.onFavorites,
  });

  final int selectedIndex;
  final String firstName;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  final VoidCallback onFavorites;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0B2638);
    const deepNavy = Color(0xFF061923);
    const teal = Color(0xFF17A99A);
    const brightTeal = Color(0xFF69E1D5);

    return Container(
      width: 245,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [navy, deepNavy],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: teal, shape: BoxShape.circle),
                child: Text(
                  firstName[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GOLDEN FINDS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Client Space',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 36),
          _ClientSideItem(
            index: 0,
            selectedIndex: selectedIndex,
            icon: Icons.home_outlined,
            label: 'Home',
            onSelected: onSelected,
          ),
          _ClientSideItem(
            index: 1,
            selectedIndex: selectedIndex,
            icon: Icons.storefront_outlined,
            label: 'Shop',
            onSelected: onSelected,
          ),
          _ClientSideItem(
            index: 2,
            selectedIndex: selectedIndex,
            icon: Icons.category_outlined,
            label: 'Categories',
            onSelected: onSelected,
          ),
          _ClientSideItem(
            index: 3,
            selectedIndex: selectedIndex,
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            onSelected: onSelected,
          ),
          _ClientSideItem(
            index: 4,
            selectedIndex: selectedIndex,
            icon: Icons.person_outline,
            label: 'Profile',
            onSelected: onSelected,
          ),
          Spacer(),
          Divider(color: Colors.white12),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onFavorites,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(Icons.favorite_border_rounded, color: brightTeal),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Favorites',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onLogout,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: brightTeal),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Sign out',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: teal),
              SizedBox(width: 8),
              Text(
                'Client account active',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientSideItem extends StatelessWidget {
  const _ClientSideItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final String label;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF17A99A);
    const brightTeal = Color(0xFF69E1D5);

    final selected = index == selectedIndex;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? teal.withValues(alpha: 0.17) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            onSelected(index);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: selected ? brightTeal : Colors.white54),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white60,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _ClientQuickAction extends StatelessWidget {
  const _ClientQuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF17A99A);
    const softTeal = Color(0xFFDDF7F3);

    return Material(
      color: GoldenDark.surface(context),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: GoldenDark.clientSoft(context, light: softTeal),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: teal),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: GoldenDark.clientInk(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: GoldenDark.muted(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: GoldenDark.clientAccent(context),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionIcon,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? actionIcon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0B2638);
    const teal = Color(0xFF17A99A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          final information = Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: teal),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: GoldenDark.clientInk(context),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: GoldenDark.muted(context),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                information,
                if (actionLabel != null) ...[
                  SizedBox(height: 18),
                  _PremiumButton(
                    label: actionLabel!,
                    icon: actionIcon ?? Icons.arrow_forward_rounded,
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    width: double.infinity,
                    onTap: onAction ?? () {},
                  ),
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: information),
              if (actionLabel != null) ...[
                SizedBox(width: 20),
                _PremiumButton(
                  label: actionLabel!,
                  icon: actionIcon ?? Icons.arrow_forward_rounded,
                  backgroundColor: navy,
                  foregroundColor: Colors.white,
                  width: 145,
                  onTap: onAction ?? () {},
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ClientProductCard extends StatelessWidget {
  const _ClientProductCard({
    required this.product,
    required this.favorite,
    required this.onFavorite,
    required this.onTap,
  });

  final ProductModel product;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0B2638);
    const softTeal = Color(0xFFDDF7F3);

    return Material(
      color: GoldenDark.surface(context),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImageView(
                    product: product,
                    fit: BoxFit.cover,
                    fallback: ColoredBox(
                      color: GoldenDark.clientSoft(context, light: softTeal),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: GoldenDark.clientAccent(context),
                        size: 54,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: GoldenDark.surface(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.categoryName,
                        style: TextStyle(
                          color: GoldenDark.clientInk(context),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: GoldenDark.surface(context),
                      shape: CircleBorder(),
                      child: InkWell(
                        customBorder: CircleBorder(),
                        onTap: onFavorite,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: GoldenDark.clientAccent(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!product.inStock)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: navy.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 3),
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: GoldenDark.clientInk(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                product.formattedPrice,
                style: TextStyle(
                  color: GoldenDark.clientAccent(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 5, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      product.sellerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: GoldenDark.subtle(context),
                        fontSize: 9,
                      ),
                    ),
                  ),
                  Text(
                    product.inStock ? '${product.stock} left' : 'Out of stock',
                    style: TextStyle(
                      color: GoldenDark.muted(context),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 7),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: GoldenDark.clientAccent(context),
                    size: 17,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientCategoryCard extends StatelessWidget {
  const _ClientCategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const softTeal = Color(0xFFDDF7F3);

    return Material(
      color: GoldenDark.surface(context),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: GoldenDark.clientSoft(context, light: softTeal),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: GoldenDark.clientAccent(context),
                  size: 30,
                ),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: GoldenDark.clientInk(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: GoldenDark.muted(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: GoldenDark.clientAccent(context),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopFilterChip extends StatelessWidget {
  const _ShopFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0B2638);
    const teal = Color(0xFF17A99A);

    return Material(
      color: selected ? navy : Colors.white,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: selected ? navy : teal.withValues(alpha: 0.20),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF69E1D5) : navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientSortButton extends StatelessWidget {
  const _ClientSortButton({required this.value, required this.onSelected});

  final ProductSortOption value;
  final ValueChanged<ProductSortOption> onSelected;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF17A99A);

    return PopupMenuButton<ProductSortOption>(
      tooltip: 'Sort products',
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (context) {
        return ProductSortOption.values
            .map(
              (option) => PopupMenuItem<ProductSortOption>(
                value: option,
                child: Row(
                  children: [
                    if (option == value)
                      Icon(
                        Icons.check_rounded,
                        color: GoldenDark.clientAccent(context),
                        size: 18,
                      )
                    else
                      SizedBox(width: 18),
                    SizedBox(width: 8),
                    Text(option.label),
                  ],
                ),
              ),
            )
            .toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: GoldenDark.surface(context),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: teal.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              color: GoldenDark.clientAccent(context),
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              value.label,
              style: TextStyle(
                color: GoldenDark.clientInk(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailChip extends StatelessWidget {
  const _ProductDetailChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    const softTeal = Color(0xFFDDF7F3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: GoldenDark.clientSoft(context, light: softTeal),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: GoldenDark.clientAccent(context), size: 15),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: GoldenDark.clientInk(context),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientCatalogueMessage extends StatelessWidget {
  const _ClientCatalogueMessage({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    const softTeal = Color(0xFFDDF7F3);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Container(
          constraints: BoxConstraints(maxWidth: 520),
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: GoldenDark.surface(context),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: GoldenDark.clientSoft(context, light: softTeal),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: GoldenDark.clientAccent(context),
                  size: 32,
                ),
              ),
              SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GoldenDark.clientInk(context),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GoldenDark.muted(context),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractiveOrderStatusChip extends StatelessWidget {
  const _InteractiveOrderStatusChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0B2638);
    const teal = Color(0xFF17A99A);

    return Material(
      color: selected ? navy : Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? navy : teal.withValues(alpha: 0.20),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : navy,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientOrderCard extends StatelessWidget {
  const _ClientOrderCard({required this.order, required this.products});

  final OrderModel order;
  final List<ProductModel> products;

  ProductModel? _findProduct(String productId) {
    for (final product in products) {
      if (product.id == productId) {
        return product;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF17A99A);
    const softTeal = Color(0xFFDDF7F3);

    Color statusColor() {
      switch (order.status) {
        case 'accepted':
          return const Color(0xFF2E6EA6);
        case 'completed':
          return const Color(0xFF267A4A);
        case 'cancelled':
          return Colors.redAccent;
        case 'pending':
        default:
          return const Color(0xFFC98918);
      }
    }

    Future<void> sendWhatsApp() async {
      final opened = await const WhatsappService().sendOrder(order);

      if (!context.mounted) {
        return;
      }

      if (!opened) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'WhatsApp could not be opened. Install WhatsApp and try again.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GoldenDark.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: teal.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: GoldenDark.clientSoft(context, light: softTeal),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.shopping_bag_outlined, color: teal),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.sellerName.isEmpty
                          ? 'Golden Finds seller'
                          : order.sellerName,
                      style: TextStyle(
                        color: GoldenDark.clientInk(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Order ${order.id} • ${order.createdAtLabel}',
                      style: TextStyle(
                        color: GoldenDark.subtle(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor().withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  order.statusLabel,
                  style: TextStyle(
                    color: statusColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 17),
          for (final item in order.items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ClientOrderItemImage(
                  item: item,
                  product: _findProduct(item.productId),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    '${item.quantity} × ${item.name}',
                    style: TextStyle(
                      color: GoldenDark.clientInk(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  OrderModel.formatMoney(item.lineTotal, item.currency),
                  style: TextStyle(
                    color: GoldenDark.clientAccent(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 9),
          ],
          Divider(height: 25),
          if (order.hasCheckoutDetails) ...[
            _ClientOrderDetailLine(
              label: 'Subtotal',
              value: order.formattedSubtotal,
            ),
            _ClientOrderDetailLine(
              label: 'Delivery fee',
              value: order.formattedDeliveryFee,
            ),
            _ClientOrderDetailLine(
              label: 'Total',
              value: order.formattedTotal,
              strong: true,
            ),
            _ClientOrderDetailLine(label: 'Currency', value: order.currency),
            _ClientOrderDetailLine(
              label: 'Delivery option',
              value: order.deliveryOptionLabel,
            ),
            if (order.deliveryOption == 'delivery')
              _ClientOrderDetailLine(
                label: 'Delivery location',
                value: order.deliveryLocation,
              ),
            if (order.deliveryPhone.trim().isNotEmpty)
              _ClientOrderDetailLine(
                label: 'Delivery phone',
                value: order.deliveryPhone,
              ),
            if (order.deliveryNotes.trim().isNotEmpty)
              _ClientOrderDetailLine(
                label: 'Delivery notes',
                value: order.deliveryNotes,
              ),
            _ClientOrderDetailLine(
              label: 'Payment method',
              value: order.paymentMethodLabel,
            ),
            _ClientOrderDetailLine(
              label: 'Payment status',
              value: order.paymentStatusLabel,
            ),
          ] else
            Row(
              children: [
                Text(
                  '${order.totalQuantity} item(s)',
                  style: TextStyle(
                    color: GoldenDark.muted(context),
                    fontSize: 11,
                  ),
                ),
                Spacer(),
                Text(
                  order.formattedTotals,
                  style: TextStyle(
                    color: GoldenDark.clientInk(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          if (order.sellerWhatsapp.trim().isNotEmpty) ...[
            SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: sendWhatsApp,
                icon: Icon(Icons.chat_rounded),
                label: Text('Send Order via WhatsApp'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClientOrderItemImage extends StatelessWidget {
  const _ClientOrderItemImage({required this.item, required this.product});

  final OrderItemModel item;
  final ProductModel? product;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;

    Widget fallback() {
      return Container(
        color: GoldenDark.clientSoft(context, light: const Color(0xFFDDF7F3)),
        alignment: Alignment.center,
        child: Icon(
          Icons.inventory_2_outlined,
          color: GoldenDark.clientAccent(context),
          size: 23,
        ),
      );
    }

    Widget image;

    if (item.imageUrl.trim().isNotEmpty) {
      image = Image.network(
        item.imageUrl.trim(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          final currentProduct = product;

          if (currentProduct != null) {
            return ProductImageView(
              product: currentProduct,
              fit: BoxFit.cover,
              fallback: fallback(),
            );
          }

          return fallback();
        },
      );
    } else if (product != null) {
      image = ProductImageView(
        product: product!,
        fit: BoxFit.cover,
        fallback: fallback(),
      );
    } else {
      image = fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

class _ClientOrderDetailLine extends StatelessWidget {
  const _ClientOrderDetailLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0B2638);
    const teal = Color(0xFF17A99A);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong
                    ? GoldenDark.clientInk(context)
                    : GoldenDark.muted(context),
                fontSize: 11,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: strong ? teal : navy,
                fontSize: strong ? 15 : 11,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyClientState extends StatelessWidget {
  const _EmptyClientState({
    required this.icon,
    required this.title,
    required this.text,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String text;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0B2638);
    const softTeal = Color(0xFFDDF7F3);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: GoldenDark.clientSoft(context, light: softTeal),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: GoldenDark.clientAccent(context),
                size: 43,
              ),
            ),
            SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GoldenDark.clientInk(context),
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 430),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GoldenDark.muted(context),
                  height: 1.45,
                ),
              ),
            ),
            SizedBox(height: 22),
            _PremiumButton(
              label: buttonText,
              icon: Icons.arrow_forward_rounded,
              backgroundColor: navy,
              foregroundColor: Colors.white,
              width: 180,
              onTap: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientProfileInfo extends StatelessWidget {
  const _ClientProfileInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF17A99A);
    const softTeal = Color(0xFFDDF7F3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: GoldenDark.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: teal.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: GoldenDark.clientSoft(context, light: softTeal),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: teal),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: GoldenDark.muted(context),
                    fontSize: 11,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: GoldenDark.clientInk(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumButton extends StatelessWidget {
  const _PremiumButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.borderColor,
    this.width,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final double? width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foregroundColor, size: 19),
              SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (width == null) {
      return button;
    }

    return SizedBox(width: width, child: button);
  }
}
