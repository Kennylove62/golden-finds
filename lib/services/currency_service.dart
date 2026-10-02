class CurrencyService {
  const CurrencyService._();

  static const List<String> supportedCurrencies = <String>['BIF', 'USD', 'EUR'];

  // Fixed examination rates. No external currency API is used.
  static const double bifPerUsd = 3000;
  static const double bifPerEur = 3300;

  // Delivery is charged once for each seller order because each seller
  // fulfils their own order separately.
  static const double deliveryFeeBifPerSeller = 5000;

  static String get exchangeRateDescription {
    return 'Fixed rates: 1 USD = 3,000 BIF • 1 EUR = 3,300 BIF';
  }

  static double convert({
    required double amount,
    required String from,
    required String to,
  }) {
    final source = from.trim().toUpperCase();
    final target = to.trim().toUpperCase();

    if (!supportedCurrencies.contains(source) ||
        !supportedCurrencies.contains(target)) {
      throw Exception('Unsupported currency conversion.');
    }

    if (source == target) {
      return amount;
    }

    final amountInBif = switch (source) {
      'USD' => amount * bifPerUsd,
      'EUR' => amount * bifPerEur,
      _ => amount,
    };

    return switch (target) {
      'USD' => amountInBif / bifPerUsd,
      'EUR' => amountInBif / bifPerEur,
      _ => amountInBif,
    };
  }

  static double deliveryFee(String currency) {
    return convert(amount: deliveryFeeBifPerSeller, from: 'BIF', to: currency);
  }

  static String format(double amount, String currency) {
    switch (currency.trim().toUpperCase()) {
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${amount.toStringAsFixed(2)}';
      case 'BIF':
      default:
        return '${amount.toStringAsFixed(0)} BIF';
    }
  }
}
