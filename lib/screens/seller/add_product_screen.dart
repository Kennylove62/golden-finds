import 'package:flutter/material.dart';

import '../../core/theme/golden_dark.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_user.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../services/catalog_service.dart';
import '../../services/product_image_service.dart';
import '../../widgets/product_image_view.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key, required this.seller, this.product});

  final AppUser seller;
  final ProductModel? product;

  bool get isEditing => product != null;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const Color wine = Color(0xFF5A1E2B);
  static const Color deepWine = Color(0xFF321016);
  static const Color cream = Color(0xFFFFF8EE);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController(
    text: '1',
  );

  final CatalogService _catalogService = CatalogService();
  final ProductImageService _imageService = ProductImageService();
  final ImagePicker _imagePicker = ImagePicker();

  late Future<List<CategoryModel>> _categoriesFuture;

  List<CategoryModel> _categories = const [];
  String? _selectedCategoryId;
  String _currency = 'BIF';

  PreparedProductImage? _preparedImage;
  String? _selectedFileName;
  String _existingImageBase64 = '';
  bool _isActive = true;

  bool _preparingImage = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    if (product != null) {
      _nameController.text = product.name;
      _descriptionController.text = product.description;
      _priceController.text = _priceText(product.price);
      _stockController.text = product.stock.toString();
      _selectedCategoryId = product.categoryId;
      _currency = product.currency.toUpperCase();
      _existingImageBase64 = product.imageBase64;
      _isActive = product.isActive;
    }

    _categoriesFuture = _loadCategories();
  }

  String _priceText(double price) {
    if (price == price.roundToDouble()) {
      return price.toStringAsFixed(0);
    }

    return price.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();

    super.dispose();
  }

  Future<List<CategoryModel>> _loadCategories() async {
    await _catalogService.ensureDefaultCategories();

    final categories = await _catalogService.getCategories();

    _categories = categories;

    if (_selectedCategoryId != null &&
        !categories.any((category) => category.id == _selectedCategoryId)) {
      final product = widget.product;

      if (product != null) {
        for (final category in categories) {
          if (category.name.trim().toLowerCase() ==
              product.categoryName.trim().toLowerCase()) {
            _selectedCategoryId = category.id;
            break;
          }
        }
      }
    }

    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    return categories;
  }

  Future<void> _retryCategories() async {
    setState(() {
      _categoriesFuture = _loadCategories();
    });
  }

  Future<void> _pickImage() async {
    if (_preparingImage || _publishing) {
      return;
    }

    try {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery);

      if (file == null) {
        return;
      }

      setState(() {
        _preparingImage = true;
      });

      final sourceBytes = await file.readAsBytes();

      final prepared = await _imageService.prepareProductImage(sourceBytes);

      if (!mounted) {
        return;
      }

      setState(() {
        _preparedImage = prepared;
        _selectedFileName = file.name;
        _preparingImage = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _preparingImage = false;
      });

      _showError(_readableError(error));
    }
  }

  Future<void> _publishProduct() async {
    if (_publishing) {
      return;
    }

    final valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    final currentProduct = widget.product;
    final hasPermanentImageUrl =
        currentProduct?.imageUrl.trim().isNotEmpty ?? false;

    final imageBase64 =
        _preparedImage?.base64Data ??
        (!hasPermanentImageUrl ? _existingImageBase64.trim() : '');

    if (imageBase64.isEmpty && !hasPermanentImageUrl) {
      _showError(
        widget.isEditing
            ? 'Keep the current image or choose a new product image.'
            : 'Choose a product image before publishing.',
      );
      return;
    }

    final categoryId = _selectedCategoryId;

    if (categoryId == null) {
      _showError('Select a product category.');
      return;
    }

    CategoryModel? selectedCategory;

    for (final category in _categories) {
      if (category.id == categoryId) {
        selectedCategory = category;
        break;
      }
    }

    if (selectedCategory == null) {
      _showError('The selected category is invalid.');
      return;
    }

    final price = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );

    final stock = int.tryParse(_stockController.text.trim());

    if (price == null || price <= 0) {
      _showError('Enter a valid product price.');
      return;
    }

    if (stock == null || stock < 0) {
      _showError('Enter a valid stock quantity.');
      return;
    }

    setState(() {
      _publishing = true;
    });

    try {
      final product = widget.product;

      if (product == null) {
        await _catalogService.createProduct(
          seller: widget.seller,
          name: _nameController.text,
          description: _descriptionController.text,
          price: price,
          currency: _currency,
          categoryId: selectedCategory.id,
          categoryName: selectedCategory.name,
          stock: stock,
          imageBase64: imageBase64,
        );
      } else {
        await _catalogService.updateProduct(
          seller: widget.seller,
          product: product,
          name: _nameController.text,
          description: _descriptionController.text,
          price: price,
          currency: _currency,
          categoryId: selectedCategory.id,
          categoryName: selectedCategory.name,
          stock: stock,
          imageBase64: imageBase64,
          isActive: _isActive,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _publishing = false;
      });

      _showError(_readableError(error));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _readableError(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoldenDark.page(context, light: cream),
      appBar: AppBar(
        backgroundColor: GoldenDark.page(context, light: cream),
        foregroundColor: GoldenDark.sellerInk(context),
        title: Text(
          widget.isEditing ? 'Edit product' : 'Add product',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<CategoryModel>>(
          future: _categoriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: wine));
            }

            if (snapshot.hasError) {
              return _CategoryLoadError(
                message: _readableError(snapshot.error!),
                onRetry: _retryCategories,
              );
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 50),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 900),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _hero(),
                        SizedBox(height: 22),
                        _imageSection(),
                        SizedBox(height: 18),
                        _detailsSection(),
                        SizedBox(height: 18),
                        _commerceSection(),
                        SizedBox(height: 24),
                        _publishButton(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [wine, deepWine],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: GoldenDark.sellerAccent(context),
            size: 34,
          ),
          SizedBox(height: 18),
          Text(
            widget.isEditing ? 'Update your product' : 'Publish a new find',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 540),
            child: Text(
              widget.isEditing
                  ? 'Change the product information, stock, visibility or image. '
                        'Only your own seller product can be updated.'
                  : 'Add a clear photo and complete product information. '
                        'The item will be saved in Firestore and later shown '
                        'to Golden Finds visitors and clients.',
              style: TextStyle(color: Colors.white60, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageSection() {
    return _FormCard(
      title: 'Product image',
      subtitle:
          'Choose one clear image. It is uploaded to Firebase Storage and its permanent URL is saved in Firestore.',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              color: GoldenDark.sellerSoft(context, light: Color(0xFFF4E7D4)),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: wine.withValues(alpha: 0.08)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _preparedImage != null
                ? Image.memory(
                    _preparedImage!.bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : widget.product != null
                ? ProductImageView(
                    product: widget.product!,
                    fit: BoxFit.cover,
                    fallback: const _ImagePlaceholder(),
                  )
                : const _ImagePlaceholder(),
          ),
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _preparingImage || _publishing ? null : _pickImage,
              icon: _preparingImage
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.photo_library_outlined),
              label: Text(
                _preparedImage == null && !widget.isEditing
                    ? 'Choose product image'
                    : 'Choose another image',
              ),
            ),
          ),
          if (_preparedImage != null ||
              (widget.product?.imageUrl.trim().isNotEmpty ?? false) ||
              widget.product?.imageBytes != null) ...[
            SizedBox(height: 11),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF268A55),
                  size: 18,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _preparedImage != null
                        ? '${_selectedFileName ?? 'Image'} • '
                              '${_preparedImage!.compressedSizeLabel}'
                        : 'Current product image • choose another image only if you want to replace it',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: GoldenDark.muted(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailsSection() {
    return _FormCard(
      title: 'Product details',
      subtitle: 'Give buyers enough information to understand the item.',
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            enabled: !_publishing,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Product name',
              hintText: 'Example: Classic leather bag',
              prefixIcon: Icon(Icons.sell_outlined),
            ),
            validator: (value) {
              if ((value ?? '').trim().length < 2) {
                return 'Enter the product name.';
              }

              return null;
            },
          ),
          SizedBox(height: 14),
          TextFormField(
            controller: _descriptionController,
            enabled: !_publishing,
            minLines: 4,
            maxLines: 7,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText:
                  'Describe the product, condition, material or important details.',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_rounded),
            ),
            validator: (value) {
              if ((value ?? '').trim().length < 5) {
                return 'Enter a useful product description.';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _commerceSection() {
    return _FormCard(
      title: 'Price and stock',
      subtitle: 'Choose the category, currency and available quantity.',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;

              final priceField = TextFormField(
                controller: _priceController,
                enabled: !_publishing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Price',
                  hintText: '0',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final price = double.tryParse(
                    (value ?? '').trim().replaceAll(',', '.'),
                  );

                  if (price == null || price <= 0) {
                    return 'Enter a valid price.';
                  }

                  return null;
                },
              );

              final stockField = TextFormField(
                controller: _stockController,
                enabled: !_publishing,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Stock',
                  hintText: '1',
                  prefixIcon: Icon(Icons.inventory_outlined),
                ),
                validator: (value) {
                  final stock = int.tryParse((value ?? '').trim());

                  if (stock == null || stock < 0) {
                    return 'Enter valid stock.';
                  }

                  return null;
                },
              );

              if (compact) {
                return Column(
                  children: [priceField, SizedBox(height: 14), stockField],
                );
              }

              return Row(
                children: [
                  Expanded(child: priceField),
                  SizedBox(width: 14),
                  Expanded(child: stockField),
                ],
              );
            },
          ),
          SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Currency',
              style: TextStyle(
                color: GoldenDark.sellerInk(context).withValues(alpha: 0.82),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final currency in const ['BIF', 'USD', 'EUR'])
                ChoiceChip(
                  label: Text(currency),
                  selected: _currency == currency,
                  onSelected: _publishing
                      ? null
                      : (_) {
                          setState(() {
                            _currency = currency;
                          });
                        },
                  selectedColor: wine,
                  labelStyle: TextStyle(
                    color: _currency == currency ? Colors.white : deepWine,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedCategoryId),
            initialValue: _selectedCategoryId,
            decoration: InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: _categories
                .map(
                  (category) => DropdownMenuItem<String>(
                    value: category.id,
                    child: Text(category.name),
                  ),
                )
                .toList(),
            onChanged: _publishing
                ? null
                : (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Select a category.';
              }

              return null;
            },
          ),
          if (widget.isEditing) ...[
            SizedBox(height: 18),
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(horizontal: 2),
              value: _isActive,
              activeThumbColor: wine,
              title: Text(
                'Public catalogue visibility',
                style: TextStyle(
                  color: GoldenDark.sellerInk(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                _isActive
                    ? 'Visible to visitors and clients.'
                    : 'Hidden from the public catalogue.',
              ),
              onChanged: _publishing
                  ? null
                  : (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
            ),
          ],
          SizedBox(height: 14),
          _SellerIdentityNote(
            sellerName: widget.seller.name,
            whatsapp: widget.seller.whatsappNumber?.trim() ?? '',
          ),
        ],
      ),
    );
  }

  Widget _publishButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: wine,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 58),
        ),
        onPressed: _publishing ? null : _publishProduct,
        icon: _publishing
            ? SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                widget.isEditing ? Icons.save_rounded : Icons.publish_rounded,
              ),
        label: Text(
          _publishing
              ? widget.isEditing
                    ? 'Saving changes...'
                    : 'Publishing...'
              : widget.isEditing
              ? 'Save changes'
              : 'Publish product',
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: GoldenDark.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF5A1E2B).withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Color(0xFF321016),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: GoldenDark.muted(context),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          color: Color(0xFF5A1E2B),
          size: 54,
        ),
        SizedBox(height: 12),
        Text(
          'No image selected',
          style: TextStyle(
            color: Color(0xFF321016),
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'JPG, PNG or WEBP',
          style: TextStyle(color: GoldenDark.subtle(context), fontSize: 10),
        ),
      ],
    );
  }
}

class _SellerIdentityNote extends StatelessWidget {
  const _SellerIdentityNote({required this.sellerName, required this.whatsapp});

  final String sellerName;
  final String whatsapp;

  @override
  Widget build(BuildContext context) {
    const wine = Color(0xFF5A1E2B);
    const amber = Color(0xFFF4B64A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: GoldenDark.sellerSoft(
          context,
          light: amber.withValues(alpha: 0.12),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined, color: wine),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              whatsapp.isEmpty
                  ? 'Seller: $sellerName • WhatsApp not provided'
                  : 'Seller: $sellerName • WhatsApp: $whatsapp',
              style: TextStyle(
                color: GoldenDark.sellerInk(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryLoadError extends StatelessWidget {
  const _CategoryLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Color(0xFF5A1E2B),
                size: 48,
              ),
              SizedBox(height: 14),
              Text(
                'Unable to load categories',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF321016),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: GoldenDark.muted(context)),
              ),
              SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
