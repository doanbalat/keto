import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  static const String _currencyKey = 'selectedCurrency';
  static const String _defaultCurrency = 'VND';

  // Currency symbols
  static const Map<String, String> _currencySymbols = {
    'VND': '₫',
    'USD': '\$',
    'EUR': '€',
  };

  // Currency locales for NumberFormat
  static const Map<String, String> _currencyLocales = {
    'VND': 'vi_VN',
    'USD': 'en_US',
    'EUR': 'de_DE',
  };

  static String _currentCurrency = _defaultCurrency;
  static NumberFormat? _numberFormatter;

  /// Initialize CurrencyService with stored currency preference
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentCurrency = prefs.getString(_currencyKey) ?? _defaultCurrency;
    _updateFormatter();
  }

  /// Get current selected currency
  static String getCurrency() {
    return _currentCurrency;
  }

  /// Get currency symbol
  static String getSymbol(String currency) {
    return _currencySymbols[currency] ?? '₫';
  }

  /// Get current currency symbol
  static String getCurrentSymbol() {
    return _currencySymbols[_currentCurrency] ?? '₫';
  }

  /// Set currency and save to SharedPreferences
  static Future<void> setCurrency(String currency) async {
    if (!_currencySymbols.containsKey(currency)) {
      throw ArgumentError('Unsupported currency: $currency');
    }

    _currentCurrency = currency;
    _updateFormatter();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, currency);
  }

  /// Format amount with current currency symbol (symbol appears after amount)
  static String formatCurrency(int amount) {
    if (_numberFormatter == null) _updateFormatter();
    final formatted = _numberFormatter!.format(amount);
    return '$formatted ${getCurrentSymbol()}';
  }

  /// Format amount with specific currency
  static String formatCurrencyWith(int amount, String currency) {
    final symbol = getSymbol(currency);
    final locale = _currencyLocales[currency] ?? 'vi_VN';
    final formatter = NumberFormat.decimalPattern(locale);
    final formatted = formatter.format(amount);
    return '$formatted $symbol';
  }

  /// Get list of available currencies
  static List<String> getAvailableCurrencies() {
    return _currencySymbols.keys.toList();
  }

  /// Update the number formatter based on current currency
  static void _updateFormatter() {
    if (!_currencySymbols.containsKey(_currentCurrency)) {
       _currentCurrency = _defaultCurrency;
    }
    final locale = _currencyLocales[_currentCurrency] ?? 'vi_VN';
    _numberFormatter = NumberFormat.decimalPattern(locale);
  }

  /// Parse currency string back to integer (removes symbol and formatting)
  static int? parseCurrency(String value) {
    // Remove currency symbol
    String cleaned = value.replaceAll(RegExp(r'[^\d-]'), '');
    return int.tryParse(cleaned);
  }
}
