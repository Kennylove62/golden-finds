import 'package:url_launcher/url_launcher.dart';

import '../models/order_model.dart';

class WhatsappService {
  const WhatsappService();

  String buildOrderMessage(OrderModel order) {
    final buffer = StringBuffer()
      ..writeln('NEW ORDER')
      ..writeln('Order ID: ${order.id}')
      ..writeln('Client: ${order.clientName}')
      ..writeln(
        'Phone: ${order.deliveryPhone.trim().isNotEmpty ? order.deliveryPhone : order.clientPhone}',
      )
      ..writeln()
      ..writeln('Products:');

    for (final item in order.items) {
      buffer.writeln(
        '- ${item.name} × ${item.quantity} '
        '(${OrderModel.formatMoney(item.lineTotal, item.currency)})',
      );
    }

    buffer
      ..writeln()
      ..writeln('Subtotal: ${order.formattedSubtotal}')
      ..writeln('Delivery: ${order.formattedDeliveryFee}')
      ..writeln('Total: ${order.formattedTotal}')
      ..writeln('Currency: ${order.currency}')
      ..writeln('Delivery option: ${order.deliveryOptionLabel}');

    if (order.deliveryOption == 'delivery') {
      buffer.writeln('Location: ${order.deliveryLocation}');
    }

    if (order.deliveryNotes.trim().isNotEmpty) {
      buffer.writeln('Delivery notes: ${order.deliveryNotes}');
    }

    buffer
      ..writeln('Payment: ${order.paymentMethodLabel}')
      ..writeln('Payment status: ${order.paymentStatusLabel}')
      ..writeln('Order status: ${order.statusLabel}');

    return buffer.toString().trim();
  }

  Future<bool> sendOrder(OrderModel order) async {
    final phone = _normalizePhone(order.sellerWhatsapp);

    if (phone.isEmpty) {
      return false;
    }

    final message = buildOrderMessage(order);

    final directWhatsApp = Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: <String, String>{'phone': phone, 'text': message},
    );

    final waMe = Uri.https('wa.me', '/$phone', <String, String>{
      'text': message,
    });

    final apiWhatsApp = Uri.https('api.whatsapp.com', '/send', <String, String>{
      'phone': phone,
      'text': message,
    });

    final candidates = <Uri>[directWhatsApp, waMe, apiWhatsApp];

    for (final uri in candidates) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          return true;
        }
      } catch (_) {
        // Try the next WhatsApp route.
      }
    }

    return false;
  }

  String _normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    // Golden Finds is a Burundi marketplace. Accept the common local
    // eight-digit format (for example 77177900) and convert it to the
    // international WhatsApp format expected by wa.me / whatsapp://.
    if (digits.length == 8) {
      digits = '257$digits';
    } else if (digits.length == 9 && digits.startsWith('0')) {
      digits = '257${digits.substring(1)}';
    }

    if (digits.length < 8 || digits.length > 15) {
      return '';
    }

    return digits;
  }
}
