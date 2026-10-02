import 'package:flutter/material.dart';

import '../../core/theme/golden_dark.dart';

import '../../models/app_user.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../services/currency_service.dart';
import '../../services/order_service.dart';
import '../../services/whatsapp_service.dart';
import '../../widgets/product_image_view.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.client,
    required this.products,
    required this.quantities,
  });

  final AppUser client;
  final List<ProductModel> products;
  final Map<String, int> quantities;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color navy = Color(0xFF0B2638);
  static const Color teal = Color(0xFF17A99A);
  static const Color ice = Color(0xFFF2F9FA);
  static const Color softTeal = Color(0xFFDDF7F3);

  final OrderService _orderService = OrderService();
  final WhatsappService _whatsappService = const WhatsappService();

  late final TextEditingController _locationController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;

  String _currency = 'BIF';
  String _deliveryOption = 'delivery';
  String _paymentMethod = 'mobile_money';

  bool _processing = false;
  bool _paymentFailed = false;

  @override
  void initState() {
    super.initState();

    _locationController = TextEditingController();
    _phoneController = TextEditingController(text: widget.client.phone);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<ProductModel> get _selectedProducts {
    return widget.products
        .where((product) => (widget.quantities[product.id] ?? 0) > 0)
        .toList();
  }

  int get _sellerCount {
    return _selectedProducts.map((product) => product.sellerId).toSet().length;
  }

  double get _subtotal {
    var total = 0.0;

    for (final product in _selectedProducts) {
      final quantity = widget.quantities[product.id] ?? 0;

      total +=
          CurrencyService.convert(
            amount: product.price,
            from: product.currency,
            to: _currency,
          ) *
          quantity;
    }

    return total;
  }

  double get _deliveryFeeTotal {
    if (_deliveryOption != 'delivery') {
      return 0;
    }

    return CurrencyService.deliveryFee(_currency) * _sellerCount;
  }

  double get _finalTotal => _subtotal + _deliveryFeeTotal;

  void _resetPaymentState() {
    if (_paymentFailed) {
      setState(() {
        _paymentFailed = false;
      });
    } else {
      setState(() {});
    }
  }

  String? _validateCheckout() {
    if (_selectedProducts.isEmpty) {
      return 'Your cart is empty.';
    }

    for (final product in _selectedProducts) {
      final quantity = widget.quantities[product.id] ?? 0;

      if (!product.isActive) {
        return '${product.name} is no longer available.';
      }

      if (product.stock <= 0) {
        return '${product.name} is out of stock.';
      }

      if (quantity > product.stock) {
        return 'Only ${product.stock} unit(s) of ${product.name} are available.';
      }
    }

    if (_deliveryOption == 'delivery') {
      if (_locationController.text.trim().length < 3) {
        return 'Enter a valid delivery location/address.';
      }

      if (_phoneController.text.trim().length < 5) {
        return 'Enter a valid delivery phone number.';
      }
    }

    if (!const {'mobile_money', 'bank_card'}.contains(_paymentMethod)) {
      return 'Select a payment method.';
    }

    return null;
  }

  Future<void> _simulateFailedPayment() async {
    if (_processing) {
      return;
    }

    final validation = _validateCheckout();

    if (validation != null) {
      _showMessage(validation);
      return;
    }

    setState(() {
      _processing = true;
      _paymentFailed = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) {
      return;
    }

    setState(() {
      _processing = false;
      _paymentFailed = true;
    });

    _showMessage(
      'Simulated payment failed. No order was created. You can retry safely.',
    );
  }

  Future<void> _payAndConfirm() async {
    if (_processing) {
      return;
    }

    final validation = _validateCheckout();

    if (validation != null) {
      _showMessage(validation);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: GoldenDark.surface(context, light: ice),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: Text(
            'Review and confirm',
            style: TextStyle(
              color: GoldenDark.clientInk(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewLine(label: 'Currency', value: _currency),
                _ReviewLine(
                  label: 'Delivery',
                  value: _deliveryOption == 'delivery'
                      ? 'Delivery'
                      : 'Physical boutique pickup',
                ),
                _ReviewLine(
                  label: 'Payment',
                  value: _paymentMethod == 'mobile_money'
                      ? 'Mobile Money'
                      : 'Bank Card',
                ),
                Divider(height: 24),
                _ReviewLine(
                  label: 'Subtotal',
                  value: CurrencyService.format(_subtotal, _currency),
                ),
                _ReviewLine(
                  label: 'Delivery fee',
                  value: CurrencyService.format(_deliveryFeeTotal, _currency),
                ),
                _ReviewLine(
                  label: 'Final total',
                  value: CurrencyService.format(_finalTotal, _currency),
                  strong: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text('Back'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: Icon(Icons.lock_rounded),
              label: Text('Simulate successful payment'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
      _paymentFailed = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));

    try {
      final orderIds = await _orderService.checkoutCart(
        client: widget.client,
        products: widget.products,
        quantities: widget.quantities,
        currency: _currency,
        deliveryOption: _deliveryOption,
        deliveryLocation: _locationController.text,
        deliveryPhone: _phoneController.text,
        deliveryNotes: _notesController.text,
        paymentMethod: _paymentMethod,
        paymentStatus: 'paid',
      );

      final orders = await _orderService.getOrdersByIds(orderIds);

      if (!mounted) {
        return;
      }

      setState(() {
        _processing = false;
      });

      await _showOrderConfirmation(orders, orderIds);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processing = false;
      });

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showOrderConfirmation(
    List<OrderModel> orders,
    List<String> orderIds,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 680,
              maxHeight: MediaQuery.sizeOf(context).height * 0.86,
            ),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: GoldenDark.surface(context, light: ice),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: GoldenDark.clientSoft(context, light: softTeal),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: GoldenDark.clientAccent(context),
                    size: 38,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Payment successful',
                  style: TextStyle(
                    color: GoldenDark.clientInk(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  orderIds.length == 1
                      ? 'Your order is stored in Firestore.'
                      : '${orderIds.length} seller orders are stored in Firestore.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: GoldenDark.muted(context)),
                ),
                SizedBox(height: 18),
                Flexible(
                  child: orders.isEmpty
                      ? ListView.separated(
                          shrinkWrap: true,
                          itemCount: orderIds.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _OrderConfirmationTile(
                              orderId: orderIds[index],
                              sellerName: 'Seller',
                              total: '',
                              product: null,
                              onWhatsapp: null,
                            );
                          },
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: orders.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            ProductModel? confirmationProduct;

                            for (final product in _selectedProducts) {
                              if (product.sellerId == order.sellerId) {
                                confirmationProduct = product;
                                break;
                              }
                            }

                            return _OrderConfirmationTile(
                              orderId: order.id,
                              sellerName: order.sellerName,
                              total: order.formattedTotal,
                              product: confirmationProduct,
                              onWhatsapp: order.sellerWhatsapp.trim().isEmpty
                                  ? null
                                  : () async {
                                      final opened = await _whatsappService
                                          .sendOrder(order);

                                      if (!mounted) {
                                        return;
                                      }

                                      if (!opened) {
                                        _showMessage(
                                          'WhatsApp could not be opened. Install WhatsApp and try again.',
                                        );
                                      }
                                    },
                            );
                          },
                        ),
                ),
                SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: Text('View my orders'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final products = _selectedProducts;

    return Scaffold(
      backgroundColor: GoldenDark.page(context, light: ice),
      appBar: AppBar(
        backgroundColor: GoldenDark.page(context, light: ice),
        foregroundColor: GoldenDark.clientInk(context),
        elevation: 0,
        title: Text('Checkout', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: products.isEmpty
            ? Center(
                child: Text(
                  'Your cart is empty.',
                  style: TextStyle(
                    color: GoldenDark.clientInk(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _section(
                          icon: Icons.currency_exchange_rounded,
                          title: '1. Select currency',
                          subtitle: CurrencyService.exchangeRateDescription,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final currency
                                  in CurrencyService.supportedCurrencies)
                                ChoiceChip(
                                  label: Text(currency),
                                  selected: _currency == currency,
                                  onSelected: (_) {
                                    setState(() {
                                      _currency = currency;
                                      _paymentFailed = false;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 14),
                        _section(
                          icon: Icons.local_shipping_outlined,
                          title: '2. Delivery or pickup',
                          subtitle:
                              'Delivery fee is charged once for each seller order.',
                          child: Column(
                            children: [
                              _CheckoutChoiceTile(
                                selected: _deliveryOption == 'delivery',
                                icon: Icons.local_shipping_outlined,
                                title: 'Delivery',
                                subtitle:
                                    '${CurrencyService.format(CurrencyService.deliveryFee(_currency), _currency)} per seller',
                                onTap: () {
                                  setState(() {
                                    _deliveryOption = 'delivery';
                                    _paymentFailed = false;
                                  });
                                },
                              ),
                              SizedBox(height: 10),
                              _CheckoutChoiceTile(
                                selected: _deliveryOption == 'pickup',
                                icon: Icons.storefront_outlined,
                                title: 'Physical boutique pickup',
                                subtitle: 'No delivery fee',
                                onTap: () {
                                  setState(() {
                                    _deliveryOption = 'pickup';
                                    _paymentFailed = false;
                                  });
                                },
                              ),
                              if (_deliveryOption == 'delivery') ...[
                                SizedBox(height: 12),
                                TextField(
                                  controller: _locationController,
                                  onChanged: (_) => _resetPaymentState(),
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: 'Delivery location / address',
                                    hintText: 'Example: Bujumbura, Rohero...',
                                    prefixIcon: Icon(
                                      Icons.location_on_outlined,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12),
                                TextField(
                                  controller: _phoneController,
                                  onChanged: (_) => _resetPaymentState(),
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: 'Delivery phone number',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                ),
                                SizedBox(height: 12),
                                TextField(
                                  controller: _notesController,
                                  onChanged: (_) => _resetPaymentState(),
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: 'Delivery notes (optional)',
                                    hintText:
                                        'Landmark, preferred time, instructions...',
                                    prefixIcon: Icon(Icons.notes_rounded),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 14),
                        _section(
                          icon: Icons.payments_outlined,
                          title: '3. Simulated payment',
                          subtitle:
                              'This examination app does not perform real financial transactions.',
                          child: Column(
                            children: [
                              _CheckoutChoiceTile(
                                selected: _paymentMethod == 'mobile_money',
                                icon: Icons.phone_android_rounded,
                                title: 'Mobile Money',
                                subtitle: 'Simulated payment only',
                                onTap: () {
                                  setState(() {
                                    _paymentMethod = 'mobile_money';
                                    _paymentFailed = false;
                                  });
                                },
                              ),
                              SizedBox(height: 10),
                              _CheckoutChoiceTile(
                                selected: _paymentMethod == 'bank_card',
                                icon: Icons.credit_card_rounded,
                                title: 'Bank Card',
                                subtitle: 'Simulated payment only',
                                onTap: () {
                                  setState(() {
                                    _paymentMethod = 'bank_card';
                                    _paymentFailed = false;
                                  });
                                },
                              ),
                              if (_paymentFailed)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.redAccent,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Payment failed. No order was created. Retry with the successful payment button.',
                                          style: TextStyle(
                                            color: Colors.redAccent,
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
                        SizedBox(height: 14),
                        _section(
                          icon: Icons.receipt_long_outlined,
                          title: '4. Review order',
                          subtitle:
                              'Review every amount before confirming payment.',
                          child: Column(
                            children: [
                              for (final product in products) ...[
                                _ProductReviewRow(
                                  product: product,
                                  quantity: widget.quantities[product.id] ?? 0,
                                  checkoutCurrency: _currency,
                                ),
                                Divider(height: 18),
                              ],
                              _ReviewLine(
                                label: 'Items subtotal',
                                value: CurrencyService.format(
                                  _subtotal,
                                  _currency,
                                ),
                              ),
                              _ReviewLine(
                                label: _deliveryOption == 'delivery'
                                    ? 'Delivery fee ($_sellerCount seller${_sellerCount == 1 ? '' : 's'})'
                                    : 'Pickup fee',
                                value: CurrencyService.format(
                                  _deliveryFeeTotal,
                                  _currency,
                                ),
                              ),
                              _ReviewLine(
                                label: 'Final total',
                                value: CurrencyService.format(
                                  _finalTotal,
                                  _currency,
                                ),
                                strong: true,
                              ),
                              SizedBox(height: 8),
                              _ReviewLine(
                                label: 'Selected currency',
                                value: _currency,
                              ),
                              _ReviewLine(
                                label: 'Delivery option',
                                value: _deliveryOption == 'delivery'
                                    ? 'Delivery'
                                    : 'Physical boutique pickup',
                              ),
                              if (_deliveryOption == 'delivery')
                                _ReviewLine(
                                  label: 'Location',
                                  value: _locationController.text.trim().isEmpty
                                      ? 'Not entered yet'
                                      : _locationController.text.trim(),
                                ),
                              _ReviewLine(
                                label: 'Payment method',
                                value: _paymentMethod == 'mobile_money'
                                    ? 'Mobile Money'
                                    : 'Bank Card',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 18),
                        if (_processing)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(color: teal),
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 620;

                              final failedButton = OutlinedButton.icon(
                                onPressed: _simulateFailedPayment,
                                icon: Icon(Icons.error_outline_rounded),
                                label: Text('Simulate failed payment'),
                              );

                              final successButton = FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: navy,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 54),
                                ),
                                onPressed: _payAndConfirm,
                                icon: Icon(Icons.lock_rounded),
                                label: Text('Pay & confirm order'),
                              );

                              if (compact) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    failedButton,
                                    SizedBox(height: 10),
                                    successButton,
                                  ],
                                );
                              }

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  failedButton,
                                  SizedBox(width: 12),
                                  successButton,
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GoldenDark.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: navy.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: GoldenDark.clientSoft(context, light: softTeal),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: teal),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: GoldenDark.clientInk(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: GoldenDark.muted(context),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CheckoutChoiceTile extends StatelessWidget {
  const _CheckoutChoiceTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0B2638);
    const teal = Color(0xFF17A99A);
    const softTeal = Color(0xFFDDF7F3);

    return Material(
      color: selected ? softTeal : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? teal.withValues(alpha: 0.45)
                  : navy.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? GoldenDark.clientAccent(context)
                    : GoldenDark.muted(context),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? navy : Colors.black87,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
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
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? teal : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductReviewRow extends StatelessWidget {
  const _ProductReviewRow({
    required this.product,
    required this.quantity,
    required this.checkoutCurrency,
  });

  final ProductModel product;
  final int quantity;
  final String checkoutCurrency;

  @override
  Widget build(BuildContext context) {
    final unitPrice = CurrencyService.convert(
      amount: product.price,
      from: product.currency,
      to: checkoutCurrency,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CheckoutProductImage(product: product),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: TextStyle(
                  color: GoldenDark.clientInk(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                '$quantity × ${CurrencyService.format(unitPrice, checkoutCurrency)}',
                style: TextStyle(
                  color: GoldenDark.muted(context),
                  fontSize: 11,
                ),
              ),
              if (product.currency.toUpperCase() != checkoutCurrency)
                Text(
                  'Original price: ${product.formattedPrice}',
                  style: TextStyle(
                    color: GoldenDark.subtle(context),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: 12),
        Text(
          CurrencyService.format(unitPrice * quantity, checkoutCurrency),
          style: TextStyle(
            color: GoldenDark.clientAccent(context),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _CheckoutProductImage extends StatelessWidget {
  const _CheckoutProductImage({required this.product, this.size = 62});

  final ProductModel product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: GoldenDark.clientSoft(context, light: const Color(0xFFDDF7F3)),
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        color: GoldenDark.clientAccent(context),
        size: size * 0.42,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: ProductImageView(
          product: product,
          fit: BoxFit.cover,
          fallback: fallback,
        ),
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: strong ? teal : navy,
                fontSize: strong ? 17 : 13,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderConfirmationTile extends StatelessWidget {
  const _OrderConfirmationTile({
    required this.orderId,
    required this.sellerName,
    required this.total,
    required this.product,
    required this.onWhatsapp,
  });

  final String orderId;
  final String sellerName;
  final String total;
  final ProductModel? product;
  final Future<void> Function()? onWhatsapp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GoldenDark.surface(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product != null) ...[
                _CheckoutProductImage(product: product!, size: 54),
                SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sellerName.trim().isEmpty
                          ? 'Golden Finds seller'
                          : sellerName,
                      style: TextStyle(
                        color: GoldenDark.clientInk(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Order ID: $orderId',
                      style: TextStyle(
                        color: GoldenDark.muted(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (total.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(
              total,
              style: TextStyle(
                color: GoldenDark.clientAccent(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (onWhatsapp != null) ...[
            SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await onWhatsapp!();
              },
              icon: Icon(Icons.chat_rounded),
              label: Text('Send Order via WhatsApp'),
            ),
          ],
        ],
      ),
    );
  }
}
