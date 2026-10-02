import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/golden_dark.dart';

import '../../models/app_user.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../models/order_model.dart';
import '../../models/app_notification.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_service.dart';
import '../../services/order_service.dart';
import '../../services/notification_service.dart';
import '../../services/product_sort_service.dart';
import '../../widgets/product_image_view.dart';
import '../shared/edit_profile_screen.dart';
import '../shared/notification_center_dialog.dart';
import 'add_product_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  static const Color wine = Color(0xFF5A1E2B);
  static const Color deepWine = Color(0xFF321016);
  static const Color amber = Color(0xFFF4B64A);
  static const Color lightAmber = Color(0xFFFFD889);
  static const Color cream = Color(0xFFFFF8EE);

  int _selectedIndex = 0;
  String _productSearch = '';
  String? _selectedProductCategoryId;
  String? _selectedProductCategoryName;
  ProductSortOption _sellerSortOption = ProductSortOption.recommended;

  final CatalogService _catalogService = CatalogService();
  final OrderService _orderService = OrderService();
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<List<AppNotification>>? _notificationSubscription;
  List<AppNotification> _notifications = const <AppNotification>[];

  late final Stream<List<ProductModel>> _dashboardProductsStream;
  late final Stream<List<OrderModel>> _dashboardOrdersStream;
  late final Stream<List<CategoryModel>> _dashboardCategoriesStream;

  String _selectedOrderStatus = 'all';
  final Set<String> _updatingOrderIds = <String>{};

  @override
  void initState() {
    super.initState();

    _dashboardProductsStream = _createDashboardProductsStream();

    _dashboardOrdersStream = _createDashboardOrdersStream();

    _dashboardCategoriesStream = _createDashboardCategoriesStream();

    _notificationSubscription = _createNotificationStream().listen(
      _applyRemoteNotifications,
    );
  }

  Stream<List<ProductModel>> _createDashboardProductsStream() {
    try {
      return _catalogService.watchSellerProducts(widget.user.uid);
    } catch (_) {
      return Stream<List<ProductModel>>.value(const <ProductModel>[]);
    }
  }

  Stream<List<OrderModel>> _createDashboardOrdersStream() {
    try {
      return _orderService.watchSellerOrders(widget.user.uid);
    } catch (_) {
      return Stream<List<OrderModel>>.value(const <OrderModel>[]);
    }
  }

  Stream<List<CategoryModel>> _createDashboardCategoriesStream() {
    try {
      return _catalogService.watchCategories();
    } catch (_) {
      return Stream<List<CategoryModel>>.value(const <CategoryModel>[]);
    }
  }

  Map<String, double> _completedSalesTotals(List<OrderModel> orders) {
    final totals = <String, double>{};

    for (final order in orders) {
      if (order.status != 'completed') {
        continue;
      }

      for (final entry in order.totals.entries) {
        final currency = entry.key.trim().toUpperCase();

        if (currency.isEmpty) {
          continue;
        }

        totals[currency] = (totals[currency] ?? 0) + entry.value;
      }
    }

    return totals;
  }

  String _formatDashboardSales(List<OrderModel> orders) {
    final totals = _completedSalesTotals(orders);

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
          title: 'Seller notifications',
          notifications: _notifications,
          primaryColor: GoldenDark.sellerInk(context),
          accentColor: GoldenDark.sellerAccent(context),
          backgroundColor: GoldenDark.surface(context, light: cream),
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

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  String get firstName {
    final name = widget.user.name.trim();

    if (name.isEmpty) {
      return 'Seller';
    }

    return name.split(RegExp(r'\s+')).first;
  }

  String get whatsapp {
    final value = widget.user.whatsappNumber?.trim() ?? '';

    if (value.isEmpty) {
      return 'Not provided';
    }

    return value;
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

  Future<void> _openAddProduct() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddProductScreen(seller: widget.user)),
    );

    if (!mounted || created != true) {
      return;
    }

    _selectPage(1);
    _showMessage('Product published successfully.');
  }

  Future<void> _openEditProduct(ProductModel product) async {
    if (product.sellerId != widget.user.uid) {
      _showMessage('You cannot edit another seller product.');
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(seller: widget.user, product: product),
      ),
    );

    if (!mounted || updated != true) {
      return;
    }

    _selectPage(1);
    _showMessage('Product updated successfully.');
  }

  void _openSellerCategory(CategoryModel category) {
    setState(() {
      _selectedProductCategoryId = category.id;
      _selectedProductCategoryName = category.name;
      _productSearch = '';
      _selectedIndex = 1;
    });
  }

  void _clearProductCategoryFilter() {
    setState(() {
      _selectedProductCategoryId = null;
      _selectedProductCategoryName = null;
    });
  }

  int _sellerProductCountForCategory(
    List<ProductModel> products,
    CategoryModel category,
  ) {
    return products.where((product) {
      if (product.categoryId.trim() == category.id.trim()) {
        return true;
      }

      return product.categoryName.trim().toLowerCase() ==
          category.name.trim().toLowerCase();
    }).length;
  }

  IconData _categoryIcon(CategoryModel category) {
    final value = '${category.slug} ${category.name}'.toLowerCase();

    if (value.contains('shoe') || value.contains('sneaker')) {
      return Icons.directions_run_outlined;
    }

    if (value.contains('fashion') ||
        value.contains('clothing') ||
        value.contains('cloth')) {
      return Icons.checkroom_outlined;
    }

    if (value.contains('beauty') || value.contains('cosmetic')) {
      return Icons.spa_outlined;
    }

    if (value.contains('accessor') ||
        value.contains('watch') ||
        value.contains('jewel')) {
      return Icons.watch_outlined;
    }

    if (value.contains('phone') ||
        value.contains('electronic') ||
        value.contains('tech')) {
      return Icons.devices_other_outlined;
    }

    if (value.contains('food') || value.contains('grocery')) {
      return Icons.shopping_basket_outlined;
    }

    return Icons.category_outlined;
  }

  Future<void> _openAddCategory() async {
    final controller = TextEditingController();

    var saving = false;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final name = controller.text.trim();

              if (name.length < 2) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid category name.')),
                );

                return;
              }

              setDialogState(() {
                saving = true;
              });

              try {
                await _catalogService.createCategory(name: name);

                if (!context.mounted) {
                  return;
                }

                Navigator.pop(dialogContext, true);
              } catch (error) {
                if (!context.mounted) {
                  return;
                }

                setDialogState(() {
                  saving = false;
                });

                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.toString().replaceFirst('Exception: ', ''),
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'Add category',
                style: TextStyle(
                  color: GoldenDark.sellerInk(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!saving) {
                      submit();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Category name',
                    hintText: 'Example: Electronics',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext, false);
                        },
                  child: Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: wine,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                  ),
                  onPressed: saving ? null : submit,
                  icon: saving
                      ? SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.add_rounded),
                  label: Text(saving ? 'Creating...' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (!mounted || created != true) {
      return;
    }

    _showMessage(
      'Marketplace category created. It is now available to all sellers.',
    );
  }

  Future<void> _toggleProduct(ProductModel product) async {
    try {
      await _catalogService.setProductActive(
        seller: widget.user,
        product: product,
        active: !product.isActive,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        product.isActive
            ? 'Product hidden from the public catalogue.'
            : 'Product is now visible in the public catalogue.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Delete product?',
            style: TextStyle(
              color: GoldenDark.sellerInk(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text('Delete "${product.name}" permanently?'),
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
                'Delete',
                style: TextStyle(
                  color: Colors.redAccent,
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

    try {
      await _catalogService.deleteProduct(
        seller: widget.user,
        product: product,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Product deleted.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _acceptOrder(OrderModel order) async {
    if (_updatingOrderIds.contains(order.id)) {
      return;
    }

    setState(() {
      _updatingOrderIds.add(order.id);
    });

    try {
      await _orderService.acceptOrder(seller: widget.user, order: order);

      if (!mounted) {
        return;
      }

      _showMessage('Order accepted. Product stock was updated.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _updatingOrderIds.remove(order.id);
        });
      }
    }
  }

  Future<void> _cancelOrder(OrderModel order) async {
    if (_updatingOrderIds.contains(order.id)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Cancel order?',
            style: TextStyle(
              color: GoldenDark.sellerInk(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text('Cancel the order from ${order.clientName}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text('Back'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Cancel order',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _updatingOrderIds.add(order.id);
    });

    try {
      await _orderService.cancelPendingOrder(seller: widget.user, order: order);

      if (!mounted) {
        return;
      }

      _showMessage('Order cancelled.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _updatingOrderIds.remove(order.id);
        });
      }
    }
  }

  Future<void> _completeOrder(OrderModel order) async {
    if (_updatingOrderIds.contains(order.id)) {
      return;
    }

    setState(() {
      _updatingOrderIds.add(order.id);
    });

    try {
      await _orderService.completeOrder(seller: widget.user, order: order);

      if (!mounted) {
        return;
      }

      _showMessage('Order completed.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _updatingOrderIds.remove(order.id);
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Sign out?',
            style: TextStyle(
              color: GoldenDark.sellerInk(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Do you want to leave your Golden Finds seller account?',
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
                  color: GoldenDark.sellerInk(context),
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
    final desktop = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: GoldenDark.page(context, light: cream),
      body: SafeArea(
        child: desktop
            ? Row(
                children: [
                  _SellerSideNavigation(
                    selectedIndex: _selectedIndex,
                    firstName: firstName,
                    onSelected: _selectPage,
                    onLogout: _logout,
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
              indicatorColor: amber.withValues(alpha: 0.22),
              onDestinationSelected: _selectPage,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Products',
                ),
                NavigationDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category),
                  label: 'Categories',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
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
        return _productsPage();

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
    return StreamBuilder<List<ProductModel>>(
      stream: _dashboardProductsStream,
      builder: (context, productSnapshot) {
        return StreamBuilder<List<OrderModel>>(
          stream: _dashboardOrdersStream,
          builder: (context, orderSnapshot) {
            return StreamBuilder<List<CategoryModel>>(
              stream: _dashboardCategoriesStream,
              builder: (context, categorySnapshot) {
                final products = productSnapshot.data ?? const <ProductModel>[];

                final orders = orderSnapshot.data ?? const <OrderModel>[];

                // Keep the marketplace-category stream attached so this
                // dashboard still reacts when the shared catalogue changes.
                final _ = categorySnapshot.data ?? const <CategoryModel>[];

                final productValue = productSnapshot.hasError
                    ? '—'
                    : '${products.length}';

                final orderValue = orderSnapshot.hasError
                    ? '—'
                    : '${orders.length}';

                final salesValue = orderSnapshot.hasError
                    ? '—'
                    : _formatDashboardSales(orders);

                final usedCategoryKeys = products
                    .map(
                      (product) => product.categoryId.trim().isNotEmpty
                          ? product.categoryId.trim().toLowerCase()
                          : product.categoryName.trim().toLowerCase(),
                    )
                    .where((value) => value.isNotEmpty)
                    .toSet();

                final categoryValue = productSnapshot.hasError
                    ? '—'
                    : '${usedCategoryKeys.length}';

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _SellerTopHeader(
                        firstName: firstName,
                        onProfile: () {
                          _selectPage(4);
                        },
                        onNotifications: _showNotifications,
                        notificationCount: _unreadNotificationCount,
                      ),
                    ),
                    SliverToBoxAdapter(child: _sellerHero()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 0, 24, 15),
                        child: Text(
                          'Business overview',
                          style: TextStyle(
                            color: GoldenDark.sellerInk(context),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                      sliver: SliverGrid(
                        delegate: SliverChildListDelegate([
                          _SellerMetricCard(
                            icon: Icons.inventory_2_outlined,
                            value: productValue,
                            label: 'Products',
                          ),
                          _SellerMetricCard(
                            icon: Icons.receipt_long_outlined,
                            value: orderValue,
                            label: 'Orders',
                          ),
                          _SellerMetricCard(
                            icon: Icons.payments_outlined,
                            value: salesValue,
                            label: 'Completed sales',
                          ),
                          _SellerMetricCard(
                            icon: Icons.category_outlined,
                            value: categoryValue,
                            label: 'Used categories',
                          ),
                        ]),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 320,
                              mainAxisExtent: 150,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 0, 24, 14),
                        child: Text(
                          'Seller tools',
                          style: TextStyle(
                            color: GoldenDark.sellerInk(context),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                      sliver: SliverGrid(
                        delegate: SliverChildListDelegate([
                          _SellerToolCard(
                            icon: Icons.add_box_outlined,
                            title: 'Add product',
                            subtitle:
                                'Publish a new item to your real Firestore catalogue.',
                            onTap: _openAddProduct,
                          ),
                          _SellerToolCard(
                            icon: Icons.inventory_2_outlined,
                            title: 'Manage products',
                            subtitle:
                                'Search products, review stock and manage catalogue visibility.',
                            onTap: () {
                              _selectPage(1);
                            },
                          ),
                          _SellerToolCard(
                            icon: Icons.category_outlined,
                            title: 'Categories',
                            subtitle:
                                'Review the product categories currently available in Firestore.',
                            onTap: () {
                              _selectPage(2);
                            },
                          ),
                          _SellerToolCard(
                            icon: Icons.receipt_long_outlined,
                            title: 'Orders',
                            subtitle:
                                'Review customer orders and update their status.',
                            onTap: () {
                              _selectPage(3);
                            },
                          ),
                        ]),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 430,
                              mainAxisExtent: 180,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sellerHero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 4, 24, 30),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [wine, deepWine],
        ),
        boxShadow: [
          BoxShadow(
            color: wine.withValues(alpha: 0.24),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            top: -60,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [amber.withValues(alpha: 0.32), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            right: 25,
            bottom: -25,
            child: Icon(
              Icons.storefront_outlined,
              size: 170,
              color: amber.withValues(alpha: 0.11),
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
                      color: amber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: lightAmber.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'SELLER WORKSPACE',
                      style: TextStyle(
                        color: lightAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.7,
                      ),
                    ),
                  ),
                  SizedBox(height: 22),
                  Text(
                    'Welcome back,\n$firstName.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 32 : 40,
                      height: 1.03,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 480),
                    child: Text(
                      'Manage your products, categories and customer orders from your dedicated Golden Finds seller space.',
                      style: TextStyle(color: Colors.white60, height: 1.5),
                    ),
                  ),
                  SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SellerButton(
                        label: 'Add product',
                        icon: Icons.add_rounded,
                        background: amber,
                        foreground: deepWine,
                        width: 155,
                        onTap: _openAddProduct,
                      ),
                      _SellerButton(
                        label: 'View orders',
                        icon: Icons.receipt_long_outlined,
                        background: Colors.transparent,
                        foreground: Colors.white,
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

  Widget _productsPage() {
    return StreamBuilder<List<ProductModel>>(
      stream: _catalogService.watchSellerProducts(widget.user.uid),
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <ProductModel>[];

        final search = _productSearch.trim().toLowerCase();

        final selectedCategoryId = _selectedProductCategoryId;
        final selectedCategoryName = _selectedProductCategoryName;

        final filteredProducts = products.where((product) {
          if (selectedCategoryId != null) {
            final exactId =
                product.categoryId.trim() == selectedCategoryId.trim();

            final legacyNameMatch =
                selectedCategoryName != null &&
                product.categoryName.trim().toLowerCase() ==
                    selectedCategoryName.trim().toLowerCase();

            if (!exactId && !legacyNameMatch) {
              return false;
            }
          }

          if (search.isEmpty) {
            return true;
          }

          return product.name.toLowerCase().contains(search) ||
              product.categoryName.toLowerCase().contains(search) ||
              product.description.toLowerCase().contains(search);
        }).toList();

        final visibleProducts = ProductSortService.sort(
          filteredProducts,
          _sellerSortOption,
          inStockFirstForRecommended: false,
        );

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _SellerPageHeader(
                icon: Icons.inventory_2_outlined,
                title: 'My Products',
                subtitle: _selectedProductCategoryName != null
                    ? '${visibleProducts.length} product${visibleProducts.length == 1 ? '' : 's'} in ${_selectedProductCategoryName!}.'
                    : products.isEmpty
                    ? 'Create and manage the products you sell on Golden Finds.'
                    : '${products.length} product${products.length == 1 ? '' : 's'} in your seller catalogue.',
                actionLabel: 'Add product',
                onAction: _openAddProduct,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _productSearch = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search your products...',
                        prefixIcon: Icon(Icons.search_rounded),
                        suffixIcon: _productSearch.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  setState(() {
                                    _productSearch = '';
                                  });
                                },
                                icon: Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _SellerSortButton(
                        value: _sellerSortOption,
                        onSelected: (value) {
                          setState(() {
                            _sellerSortOption = value;
                          });
                        },
                      ),
                    ),
                    if (_selectedProductCategoryName != null) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
                        decoration: BoxDecoration(
                          color: amber.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: amber.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_alt_outlined,
                              color: GoldenDark.sellerInk(context),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Category: ${_selectedProductCategoryName!}',
                              style: TextStyle(
                                color: GoldenDark.sellerInk(context),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 5),
                            IconButton(
                              tooltip: 'Show all products',
                              visualDensity: VisualDensity.compact,
                              onPressed: _clearProductCategoryFilter,
                              icon: Icon(Icons.close_rounded, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: wine)),
              )
            else if (snapshot.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _SellerMessageState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load products',
                  text: snapshot.error.toString(),
                ),
              )
            else if (visibleProducts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _SellerEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: products.isEmpty
                      ? 'No products yet'
                      : _selectedProductCategoryName != null
                      ? 'No products in this category'
                      : 'No matching products',
                  text: products.isEmpty
                      ? 'Your products will appear here after you publish your first item.'
                      : _selectedProductCategoryName != null
                      ? 'You have not published a product in ${_selectedProductCategoryName!} yet.'
                      : 'Try another product name, category or description.',
                  buttonText: products.isEmpty
                      ? 'Add first product'
                      : 'Add product',
                  onPressed: _openAddProduct,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                sliver: SliverGrid.builder(
                  itemCount: visibleProducts.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 420,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemBuilder: (context, index) {
                    final product = visibleProducts[index];

                    return _SellerProductCard(
                      product: product,
                      onEdit: () {
                        _openEditProduct(product);
                      },
                      onToggle: () {
                        _toggleProduct(product);
                      },
                      onDelete: () {
                        _deleteProduct(product);
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
    return StreamBuilder<List<CategoryModel>>(
      stream: _dashboardCategoriesStream,
      builder: (context, categorySnapshot) {
        final categories = categorySnapshot.data ?? const <CategoryModel>[];

        return StreamBuilder<List<ProductModel>>(
          stream: _dashboardProductsStream,
          builder: (context, productSnapshot) {
            final sellerProducts =
                productSnapshot.data ?? const <ProductModel>[];

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _SellerPageHeader(
                    icon: Icons.category_outlined,
                    title: 'Categories',
                    subtitle:
                        'Shared marketplace categories. Your products remain private to your seller account.',
                    actionLabel: 'Add marketplace category',
                    onAction: _openAddCategory,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: amber.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: amber.withValues(alpha: 0.26),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: GoldenDark.sellerInk(context),
                            size: 20,
                          ),
                          SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'Categories are shared across Golden Finds, so every seller can use the same marketplace catalogue. Clicking a category below opens only your own products in that category.',
                              style: TextStyle(
                                color: GoldenDark.sellerInk(context),
                                fontSize: 11,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (categorySnapshot.connectionState ==
                        ConnectionState.waiting &&
                    categorySnapshot.data == null)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: wine),
                    ),
                  )
                else if (categorySnapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _SellerEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Categories unavailable',
                      text:
                          'Golden Finds could not load the Firestore categories.',
                      buttonText: 'Retry',
                      onPressed: () {
                        setState(() {});
                      },
                    ),
                  )
                else if (categories.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _SellerEmptyState(
                      icon: Icons.category_outlined,
                      title: 'No categories yet',
                      text:
                          'Create the first shared category for the Golden Finds marketplace.',
                      buttonText: 'Add category',
                      onPressed: _openAddCategory,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 2, 24, 110),
                    sliver: SliverGrid.builder(
                      itemCount: categories.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 380,
                            mainAxisExtent: 160,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                      itemBuilder: (context, index) {
                        final category = categories[index];

                        final sellerCount = _sellerProductCountForCategory(
                          sellerProducts,
                          category,
                        );

                        return _SellerCategoryCard(
                          name: category.name,
                          icon: _categoryIcon(category),
                          productCount: sellerCount,
                          onTap: () {
                            _openSellerCategory(category);
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _ordersPage() {
    return StreamBuilder<List<ProductModel>>(
      stream: _catalogService.watchSellerProducts(widget.user.uid),
      builder: (context, productSnapshot) {
        final sellerProducts = productSnapshot.data ?? const <ProductModel>[];

        return StreamBuilder<List<OrderModel>>(
          stream: _orderService.watchSellerOrders(widget.user.uid),
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
                  child: _SellerPageHeader(
                    icon: Icons.receipt_long_outlined,
                    title: 'Orders',
                    subtitle:
                        'Review and process real customer orders involving your products.',
                    actionLabel: 'Live',
                    actionIcon: Icons.sync_rounded,
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
                          _SellerOrderFilterChip(
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
                    child: Center(
                      child: CircularProgressIndicator(color: wine),
                    ),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _SellerMessageState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Unable to load orders',
                      text: snapshot.error.toString(),
                    ),
                  )
                else if (visibleOrders.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _SellerEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: orders.isEmpty
                          ? 'No orders yet'
                          : 'No matching orders',
                      text: orders.isEmpty
                          ? 'Customer orders linked to your products will appear here after checkout.'
                          : 'There are no orders with this status.',
                      buttonText: 'Manage products',
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
                      separatorBuilder: (context, index) =>
                          SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final order = visibleOrders[index];

                        return _SellerOrderCard(
                          order: order,
                          products: sellerProducts,
                          busy: _updatingOrderIds.contains(order.id),
                          onAccept: () {
                            _acceptOrder(order);
                          },
                          onCancel: () {
                            _cancelOrder(order);
                          },
                          onComplete: () {
                            _completeOrder(order);
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          },
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
                    colors: [wine, deepWine],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: wine.withValues(alpha: 0.20),
                      blurRadius: 32,
                      offset: Offset(0, 15),
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
                        color: GoldenDark.sellerAccent(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: lightAmber, width: 2),
                      ),
                      child: Text(
                        firstName[0].toUpperCase(),
                        style: TextStyle(
                          color: deepWine,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      widget.user.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
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
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: amber.withValues(alpha: 0.42),
                        ),
                      ),
                      child: Text(
                        'SELLER ACCOUNT',
                        style: TextStyle(
                          color: lightAmber,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 25),
              _SellerProfileInformation(
                icon: Icons.person_outline,
                label: 'Full name',
                value: widget.user.name,
              ),
              SizedBox(height: 12),
              _SellerProfileInformation(
                icon: Icons.email_outlined,
                label: 'Email',
                value: widget.user.email,
              ),
              SizedBox(height: 12),
              _SellerProfileInformation(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: widget.user.phone.trim().isEmpty
                    ? 'Not provided'
                    : widget.user.phone,
              ),
              SizedBox(height: 12),
              _SellerProfileInformation(
                icon: Icons.chat_bubble_outline,
                label: 'WhatsApp business',
                value: whatsapp,
              ),
              SizedBox(height: 25),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 520) {
                    return Column(
                      children: [
                        _SellerButton(
                          label: 'Edit profile',
                          icon: Icons.edit_outlined,
                          background: Colors.white,
                          foreground: GoldenDark.sellerInk(context),
                          borderColor: amber,
                          width: double.infinity,
                          onTap: _openEditProfile,
                        ),
                        SizedBox(height: 12),
                        _SellerButton(
                          label: 'Sign out',
                          icon: Icons.logout_rounded,
                          background: wine,
                          foreground: Colors.white,
                          width: double.infinity,
                          onTap: _logout,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: _SellerButton(
                          label: 'Edit profile',
                          icon: Icons.edit_outlined,
                          background: Colors.white,
                          foreground: GoldenDark.sellerInk(context),
                          borderColor: amber,
                          onTap: _openEditProfile,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _SellerButton(
                          label: 'Sign out',
                          icon: Icons.logout_rounded,
                          background: wine,
                          foreground: Colors.white,
                          onTap: _logout,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerTopHeader extends StatelessWidget {
  const _SellerTopHeader({
    required this.firstName,
    required this.onProfile,
    required this.onNotifications,
    required this.notificationCount,
  });

  final String firstName;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    const wine = Color(0xFF5A1E2B);
    const amber = Color(0xFFF4B64A);

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
                color: wine,
                shape: BoxShape.circle,
              ),
              child: Text(
                firstName.isEmpty ? 'S' : firstName[0].toUpperCase(),
                style: TextStyle(
                  color: GoldenDark.sellerAccent(context),
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
                  'SELLER STUDIO',
                  style: TextStyle(
                    color: GoldenDark.sellerInk(context),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Good day, $firstName',
                  maxLines: compact ? 2 : 1,
                  softWrap: compact,
                  overflow: compact
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: GoldenDark.sellerInk(context),
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
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none_rounded, color: wine),
          ),
          if (notificationCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: amber,
                child: Text(
                  notificationCount > 9 ? '9+' : '$notificationCount',
                  style: TextStyle(
                    color: GoldenDark.sellerInk(context),
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
          notificationButton(),
          IconButton(
            tooltip: 'Profile',
            onPressed: onProfile,
            icon: const Icon(Icons.account_circle_outlined, color: wine),
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

class _SellerSideNavigation extends StatelessWidget {
  const _SellerSideNavigation({
    required this.selectedIndex,
    required this.firstName,
    required this.onSelected,
    required this.onLogout,
  });

  final int selectedIndex;
  final String firstName;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    const wine = Color(0xFF5A1E2B);
    const deepWine = Color(0xFF321016);
    const amber = Color(0xFFF4B64A);

    return Container(
      width: 248,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [wine, deepWine],
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
                decoration: BoxDecoration(
                  color: GoldenDark.sellerAccent(context),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  firstName[0].toUpperCase(),
                  style: TextStyle(
                    color: deepWine,
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
                      'Seller Studio',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 36),
          _SellerSideItem(
            index: 0,
            selectedIndex: selectedIndex,
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            onSelected: onSelected,
          ),
          _SellerSideItem(
            index: 1,
            selectedIndex: selectedIndex,
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            onSelected: onSelected,
          ),
          _SellerSideItem(
            index: 2,
            selectedIndex: selectedIndex,
            icon: Icons.category_outlined,
            label: 'Categories',
            onSelected: onSelected,
          ),
          _SellerSideItem(
            index: 3,
            selectedIndex: selectedIndex,
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            onSelected: onSelected,
          ),
          _SellerSideItem(
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
              onTap: onLogout,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: amber),
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
          SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: Color(0xFF62D48A)),
              SizedBox(width: 8),
              Text(
                'Seller account active',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SellerSideItem extends StatelessWidget {
  const _SellerSideItem({
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
    const amber = Color(0xFFF4B64A);

    final selected = index == selectedIndex;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? amber.withValues(alpha: 0.15) : Colors.transparent,
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
                Icon(icon, color: selected ? amber : Colors.white54),
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

class _SellerMetricCard extends StatelessWidget {
  const _SellerMetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    const wine = Color(0xFF5A1E2B);
    const amber = Color(0xFFF4B64A);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 210;

        final iconBox = Container(
          width: compact ? 42 : 53,
          height: compact ? 42 : 53,
          decoration: BoxDecoration(
            color: amber.withValues(alpha: 0.17),
            borderRadius: BorderRadius.circular(compact ? 13 : 16),
          ),
          child: Icon(icon, color: wine, size: compact ? 22 : 24),
        );

        final valueText = FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: GoldenDark.sellerInk(context),
              fontSize: compact ? 19 : 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        );

        final labelText = Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: GoldenDark.muted(context),
            fontSize: compact ? 10 : 11,
            height: 1.15,
          ),
        );

        return Container(
          padding: EdgeInsets.all(compact ? 14 : 20),
          decoration: BoxDecoration(
            color: GoldenDark.surface(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: wine.withValues(alpha: 0.07)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconBox,
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 24,
                      child: valueText,
                    ),
                    const SizedBox(height: 4),
                    Flexible(child: labelText),
                  ],
                )
              : Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 26,
                            child: valueText,
                          ),
                          const SizedBox(height: 3),
                          labelText,
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _SellerToolCard extends StatelessWidget {
  const _SellerToolCard({
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
    const wine = Color(0xFF5A1E2B);
    const amber = Color(0xFFF4B64A);

    return Material(
      color: GoldenDark.surface(context),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 53,
                height: 53,
                decoration: BoxDecoration(
                  color: amber.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: wine),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: GoldenDark.sellerInk(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
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
                color: GoldenDark.sellerAccent(context),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerPageHeader extends StatelessWidget {
  const _SellerPageHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    const wine = Color(0xFF5A1E2B);
    const amber = Color(0xFFF4B64A);

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
                  color: wine,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: amber),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Color(0xFF321016),
                        fontSize: 27,
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
                  _SellerButton(
                    label: actionLabel!,
                    icon: actionIcon ?? Icons.add_rounded,
                    background: wine,
                    foreground: Colors.white,
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
                _SellerButton(
                  label: actionLabel!,
                  icon: actionIcon ?? Icons.add_rounded,
                  background: wine,
                  foreground: Colors.white,
                  width: 155,
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

class _SellerProductCard extends StatelessWidget {
  const _SellerProductCard({
    required this.product,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF4B64A);

    return Material(
      color: GoldenDark.surface(context),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
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
                    fallback: Container(
                      color: GoldenDark.border(
                        context,
                        light: Color(0xFFF4E7D4),
                      ),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: GoldenDark.sellerInk(context),
                        size: 48,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: product.isActive
                            ? const Color(0xFF267A4A)
                            : GoldenDark.muted(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.isActive ? 'LIVE' : 'HIDDEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Material(
                      color: GoldenDark.surface(context),
                      shape: CircleBorder(),
                      child: PopupMenuButton<String>(
                        tooltip: 'Product actions',
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          } else if (value == 'toggle') {
                            onToggle();
                          } else if (value == 'delete') {
                            onDelete();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 19),
                                SizedBox(width: 10),
                                Text('Edit product'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  product.isActive
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 19,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  product.isActive
                                      ? 'Hide product'
                                      : 'Show product',
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 19,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Delete product',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: GoldenDark.sellerInk(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    product.formattedPrice,
                    style: TextStyle(
                      color: GoldenDark.sellerInk(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Text(
                product.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: GoldenDark.muted(context),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      product.categoryName,
                      style: TextStyle(
                        color: GoldenDark.sellerInk(context),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.inventory_2_outlined,
                    color: GoldenDark.subtle(context),
                    size: 15,
                  ),
                  SizedBox(width: 5),
                  Text(
                    '${product.stock} in stock',
                    style: TextStyle(
                      color: GoldenDark.muted(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: Icon(Icons.edit_outlined, size: 18),
                      label: Text('Edit'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent),
                      ),
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text('Delete'),
                    ),
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

class _SellerMessageState extends StatelessWidget {
  const _SellerMessageState({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: GoldenDark.sellerInk(context), size: 48),
              SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GoldenDark.sellerInk(context),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
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

class _SellerCategoryCard extends StatelessWidget {
  const _SellerCategoryCard({
    required this.name,
    required this.icon,
    required this.productCount,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final int productCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF4B64A);

    return Material(
      color: GoldenDark.surface(context),
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: amber.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(
                  icon,
                  color: GoldenDark.sellerInk(context),
                  size: 29,
                ),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: GoldenDark.sellerInk(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      productCount == 0
                          ? 'No products from you yet'
                          : '$productCount of your product${productCount == 1 ? '' : 's'}',
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
                color: GoldenDark.sellerAccent(context),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerOrderFilterChip extends StatelessWidget {
  const _SellerOrderFilterChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const wine = Color(0xFF5A1E2B);
    const amber = Color(0xFFF4B64A);

    return Material(
      color: selected ? wine : Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? wine : amber.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : wine,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

class _SellerSortButton extends StatelessWidget {
  const _SellerSortButton({required this.value, required this.onSelected});

  final ProductSortOption value;
  final ValueChanged<ProductSortOption> onSelected;

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF4B64A);

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
                        color: GoldenDark.sellerInk(context),
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
          border: Border.all(color: amber.withValues(alpha: 0.38)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              color: GoldenDark.sellerInk(context),
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              value.label,
              style: TextStyle(
                color: GoldenDark.sellerInk(context),
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

class _SellerOrderCard extends StatelessWidget {
  const _SellerOrderCard({
    required this.order,
    required this.products,
    required this.busy,
    required this.onAccept,
    required this.onCancel,
    required this.onComplete,
  });

  final OrderModel order;
  final List<ProductModel> products;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

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
    const wine = Color(0xFF5A1E2B);
    const amber = Color(0xFFF4B64A);
    const cream = Color(0xFFFFF8EE);

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: GoldenDark.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: wine.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.person_outline_rounded, color: wine),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.clientName.isEmpty
                          ? 'Golden Finds client'
                          : order.clientName,
                      style: TextStyle(
                        color: GoldenDark.sellerInk(context),
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
          if (order.clientPhone.trim().isNotEmpty) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  color: GoldenDark.subtle(context),
                  size: 16,
                ),
                SizedBox(width: 7),
                Text(
                  order.clientPhone,
                  style: TextStyle(
                    color: GoldenDark.muted(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 17),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GoldenDark.surfaceAlt(context, light: cream),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                for (final item in order.items) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SellerOrderItemImage(
                        item: item,
                        product: _findProduct(item.productId),
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          '${item.quantity} × ${item.name}',
                          style: TextStyle(
                            color: GoldenDark.sellerInk(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        OrderModel.formatMoney(item.lineTotal, item.currency),
                        style: TextStyle(
                          color: GoldenDark.sellerInk(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                ],
              ],
            ),
          ),
          SizedBox(height: 14),
          if (order.hasCheckoutDetails) ...[
            _SellerOrderDetailLine(
              label: 'Subtotal',
              value: order.formattedSubtotal,
            ),
            _SellerOrderDetailLine(
              label: 'Delivery fee',
              value: order.formattedDeliveryFee,
            ),
            _SellerOrderDetailLine(
              label: 'Total',
              value: order.formattedTotal,
              strong: true,
            ),
            _SellerOrderDetailLine(label: 'Currency', value: order.currency),
            _SellerOrderDetailLine(
              label: 'Delivery option',
              value: order.deliveryOptionLabel,
            ),
            if (order.deliveryOption == 'delivery') ...[
              _SellerOrderDetailLine(
                label: 'Delivery location',
                value: order.deliveryLocation,
              ),
              if (order.deliveryPhone.trim().isNotEmpty)
                _SellerOrderDetailLine(
                  label: 'Delivery phone',
                  value: order.deliveryPhone,
                ),
              if (order.deliveryNotes.trim().isNotEmpty)
                _SellerOrderDetailLine(
                  label: 'Delivery notes',
                  value: order.deliveryNotes,
                ),
            ],
            _SellerOrderDetailLine(
              label: 'Payment method',
              value: order.paymentMethodLabel,
            ),
            _SellerOrderDetailLine(
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
                    color: GoldenDark.sellerInk(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          if (order.status == 'pending' || order.status == 'accepted') ...[
            SizedBox(height: 18),
            if (busy)
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: GoldenDark.sellerInk(context),
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (order.status == 'pending')
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    onPressed: onCancel,
                    icon: Icon(Icons.close_rounded),
                    label: Text('Cancel'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: wine,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46),
                    ),
                    onPressed: onAccept,
                    icon: Icon(Icons.check_rounded),
                    label: Text('Accept order'),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: wine,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                  ),
                  onPressed: onComplete,
                  icon: Icon(Icons.task_alt_rounded),
                  label: Text('Mark completed'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SellerOrderItemImage extends StatelessWidget {
  const _SellerOrderItemImage({required this.item, required this.product});

  final OrderItemModel item;
  final ProductModel? product;

  @override
  Widget build(BuildContext context) {
    const size = 54.0;

    Widget fallback() {
      return Container(
        color: GoldenDark.surfaceAlt(context, light: const Color(0xFFFFF1DC)),
        alignment: Alignment.center,
        child: Icon(
          Icons.inventory_2_outlined,
          color: GoldenDark.sellerInk(context),
          size: 24,
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

class _SellerOrderDetailLine extends StatelessWidget {
  const _SellerOrderDetailLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    const wine = Color(0xFF5A1E2B);
    const amber = Color(0xFFF4B64A);

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
                    ? GoldenDark.sellerInk(context)
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
                color: strong ? amber : wine,
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

class _SellerEmptyState extends StatelessWidget {
  const _SellerEmptyState({
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
    const wine = Color(0xFF5A1E2B);
    const amber = Color(0xFFF4B64A);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: amber.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: GoldenDark.sellerInk(context), size: 42),
            ),
            SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GoldenDark.sellerInk(context),
                fontSize: 25,
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
            _SellerButton(
              label: buttonText,
              icon: Icons.arrow_forward_rounded,
              background: wine,
              foreground: Colors.white,
              width: 190,
              onTap: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerProfileInformation extends StatelessWidget {
  const _SellerProfileInformation({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    const wine = Color(0xFF5A1E2B);
    const amber = Color(0xFFF4B64A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: GoldenDark.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: wine.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: wine),
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
                    color: GoldenDark.sellerInk(context),
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

class _SellerButton extends StatelessWidget {
  const _SellerButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.borderColor,
    this.width,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final Color? borderColor;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background,
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
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 19),
              SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
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
