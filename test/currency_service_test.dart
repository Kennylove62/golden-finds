import 'package:flutter_test/flutter_test.dart';
import 'package:golden_finds/services/currency_service.dart';

void main() {
  group('CurrencyService', () {
    test('uses the documented fixed exchange rates', () {
      expect(
        CurrencyService.convert(amount: 3000, from: 'BIF', to: 'USD'),
        closeTo(1, 0.000001),
      );

      expect(
        CurrencyService.convert(amount: 3300, from: 'BIF', to: 'EUR'),
        closeTo(1, 0.000001),
      );
    });

    test('converts between foreign currencies through BIF', () {
      expect(
        CurrencyService.convert(amount: 1, from: 'USD', to: 'EUR'),
        closeTo(3000 / 3300, 0.000001),
      );
    });

    test('delivery fee is fixed at 5000 BIF per seller order', () {
      expect(CurrencyService.deliveryFee('BIF'), 5000);
      expect(
        CurrencyService.deliveryFee('USD'),
        closeTo(5000 / 3000, 0.000001),
      );
    });
  });
}
