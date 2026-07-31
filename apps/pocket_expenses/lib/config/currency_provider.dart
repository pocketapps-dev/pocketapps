import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const currencyPrefKey = 'currency';

class Currency {
  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  final String code;
  final String symbol;
  final String name;
}

const currencies = [
  Currency(code: 'EUR', symbol: '€', name: 'Euro'),
  Currency(code: 'USD', symbol: r'$', name: 'Dólar Americano'),
  Currency(code: 'GBP', symbol: '£', name: 'Libra Esterlina'),
  Currency(code: 'BRL', symbol: r'R$', name: 'Real Brasileiro'),
  Currency(code: 'JPY', symbol: '¥', name: 'Iene Japonês'),
  Currency(code: 'CHF', symbol: 'CHF', name: 'Franco Suíço'),
  Currency(code: 'CAD', symbol: r'CA$', name: 'Dólar Canadense'),
  Currency(code: 'AUD', symbol: r'A$', name: 'Dólar Australiano'),
  Currency(code: 'PLN', symbol: 'zł', name: 'Zloty Polaco'),
  Currency(code: 'CZK', symbol: 'Kč', name: 'Coroa Checa'),
];

Currency currencyByCode(String code) =>
    currencies.firstWhere((c) => c.code == code, orElse: () => currencies.first);

NumberFormat currencyFormatFor(String code) =>
    NumberFormat.currency(locale: 'pt_PT', symbol: currencyByCode(code).symbol);

class CurrencyNotifier extends Notifier<String> {
  CurrencyNotifier({this.initial = 'EUR'});

  final String initial;

  @override
  String build() => initial;

  Future<void> setCurrency(String code) async {
    state = code;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(currencyPrefKey, code);
  }
}

final currencyProvider = NotifierProvider<CurrencyNotifier, String>(
  CurrencyNotifier.new,
);
