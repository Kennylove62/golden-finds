import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/golden_dark.dart';
import '../../models/product_model.dart';
import '../../services/catalog_service.dart';
import '../../services/product_sort_service.dart';
import '../../widgets/product_image_view.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

class VisitorHomeScreen extends StatefulWidget {
  const VisitorHomeScreen({super.key});

  @override
  State<VisitorHomeScreen> createState() => _VisitorHomeScreenState();
}

class _VisitorHomeScreenState extends State<VisitorHomeScreen> {
  static const Color black = Color(0xFF0B0B0B);
  static const Color deepBlack = Color(0xFF050505);
  static const Color gold = Color(0xFFD6B35A);
  static const Color brightGold = Color(0xFFF3D983);
  static const Color ivory = Color(0xFFF8F5EE);
  static const Color softIvory = Color(0xFFF0ECE2);

  final TextEditingController _searchController = TextEditingController();

  final CatalogService _catalogService = CatalogService();

  final GlobalKey _discoverSectionKey = GlobalKey();
  final GlobalKey _categoriesSectionKey = GlobalKey();
  final GlobalKey _howItWorksSectionKey = GlobalKey();

  late final Stream<List<ProductModel>> _productsStream;

  String _selectedCategory = 'All';
  ProductSortOption _sortOption = ProductSortOption.recommended;

  @override
  void initState() {
    super.initState();

    _productsStream = _createProductsStream();
  }

  Stream<List<ProductModel>> _createProductsStream() {
    try {
      return _catalogService.watchPublicProducts();
    } catch (_) {
      // Widget tests create this screen without initializing Firebase.
      // In the real application Firebase is initialized in main.dart.
      return Stream<List<ProductModel>>.value(const <ProductModel>[]);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final sectionContext = key.currentContext;

    if (sectionContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      alignment: 0.04,
    );
  }

  List<ProductModel> _visibleProducts(List<ProductModel> products) {
    final search = _searchController.text.trim().toLowerCase();

    final filtered = products.where((product) {
      final matchesCategory =
          _selectedCategory == 'All' ||
          product.categoryName == _selectedCategory;

      final matchesSearch =
          search.isEmpty ||
          product.name.toLowerCase().contains(search) ||
          product.categoryName.toLowerCase().contains(search) ||
          product.sellerName.toLowerCase().contains(search) ||
          product.description.toLowerCase().contains(search);

      return matchesCategory && matchesSearch;
    }).toList();

    return ProductSortService.sort(filtered, _sortOption);
  }

  List<String> _categories(List<ProductModel> products) {
    final names =
        products
            .map((product) => product.categoryName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return ['All', ...names];
  }

  void _openProduct(ProductModel product) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            constraints: BoxConstraints(maxWidth: 560),
            decoration: BoxDecoration(
              color: GoldenDark.surface(context, light: ivory),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 45,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 280,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ProductImageView(
                            product: product,
                            fit: BoxFit.cover,
                            fallback: Container(
                              color: GoldenDark.surfaceAlt(
                                context,
                                light: softIvory,
                              ),
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: gold,
                                size: 78,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            right: 14,
                            child: Material(
                              color: GoldenDark.surface(context),
                              shape: CircleBorder(),
                              child: InkWell(
                                customBorder: CircleBorder(),
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                },
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: GoldenDark.visitorInk(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: gold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Text(
                                      product.categoryName.toUpperCase(),
                                      style: TextStyle(
                                        color: AppTheme.darkGold,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: product.inStock
                                      ? (GoldenDark.enabled(context)
                                            ? const Color(0xFF173625)
                                            : const Color(0xFFE7F5EB))
                                      : (GoldenDark.enabled(context)
                                            ? const Color(0xFF4B252A)
                                            : const Color(0xFFFFECEC)),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  product.inStock
                                      ? '${product.stock} in stock'
                                      : 'Out of stock',
                                  style: TextStyle(
                                    color: product.inStock
                                        ? const Color(0xFF267A4A)
                                        : Colors.redAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 14),
                          Text(
                            product.name,
                            style: TextStyle(
                              color: GoldenDark.visitorInk(context),
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            product.formattedPrice,
                            style: TextStyle(
                              color: AppTheme.darkGold,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 18),
                          Text(
                            product.description,
                            style: TextStyle(
                              color: GoldenDark.muted(context),
                              height: 1.55,
                            ),
                          ),
                          SizedBox(height: 20),
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                color: GoldenDark.muted(context),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sold by ${product.sellerName}',
                                  style: TextStyle(
                                    color: GoldenDark.muted(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (product.sellerWhatsapp.trim().isNotEmpty) ...[
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  color: GoldenDark.muted(context),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Seller WhatsApp: ${product.sellerWhatsapp}',
                                    style: TextStyle(
                                      color: GoldenDark.muted(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: 25),
                          Text(
                            'You are browsing as a visitor. Sign in or create a client account when you want to continue with purchasing.',
                            style: TextStyle(
                              color: GoldenDark.muted(context),
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 22),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 400) {
                                return Column(
                                  children: [
                                    _VisitorButton(
                                      label: 'Sign in',
                                      icon: Icons.login_rounded,
                                      background: black,
                                      foreground: Colors.white,
                                      width: double.infinity,
                                      onTap: () {
                                        Navigator.pop(dialogContext);
                                        _goToLogin();
                                      },
                                    ),
                                    SizedBox(height: 10),
                                    _VisitorButton(
                                      label: 'Create account',
                                      icon: Icons.person_add_alt_1_outlined,
                                      background: Colors.white,
                                      foreground: black,
                                      borderColor: gold,
                                      width: double.infinity,
                                      onTap: () {
                                        Navigator.pop(dialogContext);
                                        _goToRegister();
                                      },
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(
                                    child: _VisitorButton(
                                      label: 'Sign in',
                                      icon: Icons.login_rounded,
                                      background: black,
                                      foreground: Colors.white,
                                      onTap: () {
                                        Navigator.pop(dialogContext);
                                        _goToLogin();
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: _VisitorButton(
                                      label: 'Create account',
                                      icon: Icons.person_add_alt_1_outlined,
                                      background: Colors.white,
                                      foreground: black,
                                      borderColor: gold,
                                      onTap: () {
                                        Navigator.pop(dialogContext);
                                        _goToRegister();
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoldenDark.page(context, light: ivory),
      body: SafeArea(
        child: StreamBuilder<List<ProductModel>>(
          stream: _productsStream,
          builder: (context, snapshot) {
            final products = snapshot.data ?? const <ProductModel>[];

            final categories = _categories(products);

            if (!categories.contains(_selectedCategory)) {
              _selectedCategory = 'All';
            }

            final visibleProducts = _visibleProducts(products);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _topNavigation()),
                SliverToBoxAdapter(child: _hero()),
                SliverToBoxAdapter(
                  child: KeyedSubtree(
                    key: _categoriesSectionKey,
                    child: _categorySection(categories),
                  ),
                ),
                SliverToBoxAdapter(
                  child: KeyedSubtree(
                    key: _discoverSectionKey,
                    child: _productsHeader(visibleProducts.length),
                  ),
                ),
                _productsGrid(
                  products: visibleProducts,
                  loading:
                      snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null,
                  error: snapshot.hasError ? snapshot.error.toString() : null,
                ),
                SliverToBoxAdapter(
                  child: KeyedSubtree(
                    key: _howItWorksSectionKey,
                    child: _howItWorks(),
                  ),
                ),
                SliverToBoxAdapter(child: _joinSection()),
                SliverToBoxAdapter(child: _VisitorFooter()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topNavigation() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;

        return Container(
          padding: EdgeInsets.fromLTRB(
            mobile ? 18 : 32,
            18,
            mobile ? 18 : 32,
            16,
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(color: black, shape: BoxShape.circle),
                child: Icon(Icons.diamond_outlined, color: gold, size: 23),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GOLDEN FINDS',
                      style: TextStyle(
                        color: GoldenDark.visitorInk(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.7,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Discover extraordinary finds',
                      style: TextStyle(
                        color: GoldenDark.muted(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (!mobile) ...[
                _SimpleNavItem(
                  label: 'Discover',
                  onTap: () {
                    _scrollToSection(_discoverSectionKey);
                  },
                ),
                _SimpleNavItem(
                  label: 'Categories',
                  onTap: () {
                    _scrollToSection(_categoriesSectionKey);
                  },
                ),
                _SimpleNavItem(
                  label: 'How it works',
                  onTap: () {
                    _scrollToSection(_howItWorksSectionKey);
                  },
                ),
                SizedBox(width: 14),
              ],
              _VisitorButton(
                label: 'Sign in',
                icon: Icons.login_rounded,
                background: black,
                foreground: Colors.white,
                width: mobile ? 105 : 120,
                onTap: _goToLogin,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 42),
      child: Container(
        constraints: BoxConstraints(minHeight: 360),
        padding: const EdgeInsets.all(34),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [black, deepBlack],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [gold.withValues(alpha: 0.25), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 35,
              bottom: -15,
              child: Icon(
                Icons.diamond_outlined,
                size: 180,
                color: gold.withValues(alpha: 0.10),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final mobile = constraints.maxWidth < 650;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: gold.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        'VISITOR MODE',
                        style: TextStyle(
                          color: brightGold,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    SizedBox(height: 22),
                    Text(
                      'Discover something\nextraordinary.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: mobile ? 36 : 50,
                        height: 0.98,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 520),
                      child: Text(
                        'Explore real products published by Golden Finds sellers without creating an account.',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ),
                    SizedBox(height: 26),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 560),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) {
                          setState(() {});
                        },
                        style: TextStyle(color: black),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: GoldenDark.field(context),
                          hintText: 'Search products, categories or sellers...',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: AppTheme.darkGold,
                          ),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: Icon(Icons.close_rounded),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _VisitorButton(
                          label: 'Create account',
                          icon: Icons.person_add_alt_1_outlined,
                          background: gold,
                          foreground: deepBlack,
                          width: 170,
                          onTap: _goToRegister,
                        ),
                        _VisitorButton(
                          label: 'Explore freely',
                          icon: Icons.explore_outlined,
                          background: Colors.transparent,
                          foreground: Colors.white,
                          borderColor: Colors.white24,
                          width: 155,
                          onTap: () {
                            _scrollToSection(_discoverSectionKey);
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
      ),
    );
  }

  Widget _categorySection(List<String> categories) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Browse by category',
            style: TextStyle(
              color: GoldenDark.visitorInk(context),
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Categories are generated from products currently available on Golden Finds.',
            style: TextStyle(color: GoldenDark.muted(context), fontSize: 12),
          ),
          SizedBox(height: 17),
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (context, index) => SizedBox(width: 10),
              itemBuilder: (context, index) {
                final category = categories[index];

                return _CategoryFilter(
                  label: category,
                  selected: _selectedCategory == category,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _productsHeader(int visible) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;

          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore products',
                style: TextStyle(
                  color: GoldenDark.visitorInk(context),
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Live public catalogue from Firestore',
                style: TextStyle(
                  color: GoldenDark.muted(context),
                  fontSize: 11,
                ),
              ),
            ],
          );

          final controls = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: GoldenDark.surfaceAlt(context, light: softIvory),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '$visible items',
                  style: TextStyle(
                    color: AppTheme.darkGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _VisitorSortButton(
                value: _sortOption,
                onSelected: (value) {
                  setState(() {
                    _sortOption = value;
                  });
                },
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, SizedBox(height: 14), controls],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              SizedBox(width: 16),
              controls,
            ],
          );
        },
      ),
    );
  }

  Widget _productsGrid({
    required List<ProductModel> products,
    required bool loading,
    required String? error,
  }) {
    if (loading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 40, 24, 80),
          child: Center(child: CircularProgressIndicator(color: black)),
        ),
      );
    }

    if (error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 25, 24, 70),
          child: _VisitorMessageState(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to load catalogue',
            text: error,
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 30, 24, 80),
          child: _EmptyVisitorState(),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 60),
      sliver: SliverGrid.builder(
        itemCount: products.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
          mainAxisExtent: 255,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemBuilder: (context, index) {
          final product = products[index];

          return _VisitorProductCard(
            product: product,
            onTap: () {
              _openProduct(product);
            },
          );
        },
      ),
    );
  }

  Widget _howItWorks() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 54),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: GoldenDark.surface(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: GoldenDark.border(context, light: const Color(0xFFE7E0D2)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;

          const items = [
            _VisitorInfoItem(
              icon: Icons.search_rounded,
              number: '01',
              title: 'Explore freely',
              text: 'Browse live public products without an account.',
            ),
            _VisitorInfoItem(
              icon: Icons.visibility_outlined,
              number: '02',
              title: 'View details',
              text: 'Open a product to see its price, stock and seller.',
            ),
            _VisitorInfoItem(
              icon: Icons.login_rounded,
              number: '03',
              title: 'Join when ready',
              text: 'Sign in or create an account when you want to buy.',
            ),
          ];

          if (mobile) {
            return Column(
              children: [
                items[0],
                SizedBox(height: 22),
                Divider(),
                SizedBox(height: 22),
                items[1],
                SizedBox(height: 22),
                Divider(),
                SizedBox(height: 22),
                items[2],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: items[0]),
              SizedBox(width: 28),
              Expanded(child: items[1]),
              SizedBox(width: 28),
              Expanded(child: items[2]),
            ],
          );
        },
      ),
    );
  }

  Widget _joinSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 54),
      padding: const EdgeInsets.all(34),
      decoration: BoxDecoration(
        color: black,
        borderRadius: BorderRadius.circular(30),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 650;

          if (mobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _JoinText(),
                SizedBox(height: 24),
                _VisitorButton(
                  label: 'Create an account',
                  icon: Icons.person_add_alt_1_outlined,
                  background: gold,
                  foreground: deepBlack,
                  width: double.infinity,
                  onTap: _goToRegister,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: _JoinText()),
              SizedBox(width: 32),
              _VisitorButton(
                label: 'Create an account',
                icon: Icons.person_add_alt_1_outlined,
                background: gold,
                foreground: deepBlack,
                width: 190,
                onTap: _goToRegister,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VisitorSortButton extends StatelessWidget {
  const _VisitorSortButton({required this.value, required this.onSelected});

  final ProductSortOption value;
  final ValueChanged<ProductSortOption> onSelected;

  @override
  Widget build(BuildContext context) {
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
                        color: AppTheme.darkGold,
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: GoldenDark.surface(context),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, color: AppTheme.darkGold, size: 18),
            SizedBox(width: 7),
            Text(
              value.label,
              style: TextStyle(
                color: AppTheme.black,
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

class _VisitorProductCard extends StatelessWidget {
  const _VisitorProductCard({required this.product, required this.onTap});

  final ProductModel product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD6B35A);
    const softIvory = Color(0xFFF0ECE2);

    return Material(
      color: GoldenDark.surface(context),
      borderRadius: BorderRadius.circular(22),
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
                    fallback: Container(
                      color: GoldenDark.surfaceAlt(context, light: softIvory),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: gold,
                        size: 46,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 9,
                    left: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: GoldenDark.surface(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.categoryName,
                        style: TextStyle(
                          color: GoldenDark.muted(context),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 3),
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: GoldenDark.visitorInk(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Text(
                product.formattedPrice,
                style: TextStyle(
                  color: AppTheme.darkGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 4, 13, 10),
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
                  SizedBox(width: 8),
                  Text(
                    product.inStock ? '${product.stock} left' : 'Out',
                    style: TextStyle(
                      color: GoldenDark.muted(context),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 7),
                  Icon(Icons.arrow_outward_rounded, color: gold, size: 15),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const black = Color(0xFF0B0B0B);
    const gold = Color(0xFFD6B35A);

    return Material(
      color: selected ? black : Colors.white,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: selected ? black : gold.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFFF3D983) : black,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SimpleNavItem extends StatelessWidget {
  const _SimpleNavItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = GoldenDark.enabled(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                color: dark ? Colors.white70 : const Color(0xFF4E4A43),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisitorButton extends StatelessWidget {
  const _VisitorButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.width,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final double? width;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: background,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
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
      return content;
    }

    return SizedBox(width: width, child: content);
  }
}

class _VisitorInfoItem extends StatelessWidget {
  const _VisitorInfoItem({
    required this.icon,
    required this.number,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFD6B35A).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF9F7A23), size: 21),
            ),
            Spacer(),
            Text(
              number,
              style: TextStyle(
                color: Colors.black12,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            color: Color(0xFF0B0B0B),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          text,
          style: TextStyle(
            color: GoldenDark.muted(context),
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _JoinText extends StatelessWidget {
  const _JoinText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Found something you like?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Create a client account when you are ready to start buying.',
          style: TextStyle(color: Colors.white54, height: 1.45),
        ),
      ],
    );
  }
}

class _EmptyVisitorState extends StatelessWidget {
  const _EmptyVisitorState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(38),
      decoration: BoxDecoration(
        color: GoldenDark.surface(context),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, color: Color(0xFFD6B35A), size: 46),
          SizedBox(height: 14),
          Text(
            'No products found',
            style: TextStyle(
              color: Color(0xFF0B0B0B),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'No public product matches this search or category.',
            textAlign: TextAlign.center,
            style: TextStyle(color: GoldenDark.muted(context)),
          ),
        ],
      ),
    );
  }
}

class _VisitorMessageState extends StatelessWidget {
  const _VisitorMessageState({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(34),
      decoration: BoxDecoration(
        color: GoldenDark.surface(context),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFD6B35A), size: 46),
          SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF0B0B0B),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: GoldenDark.muted(context)),
          ),
        ],
      ),
    );
  }
}

class _VisitorFooter extends StatelessWidget {
  const _VisitorFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 30),
      child: Column(
        children: [
          Divider(color: GoldenDark.border(context, light: Color(0xFFE4DED2))),
          SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: [
              Icon(Icons.diamond_outlined, color: Color(0xFFD6B35A), size: 20),
              Text(
                'GOLDEN FINDS',
                style: TextStyle(
                  color: Color(0xFF0B0B0B),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Public marketplace experience',
                style: TextStyle(
                  color: GoldenDark.subtle(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
