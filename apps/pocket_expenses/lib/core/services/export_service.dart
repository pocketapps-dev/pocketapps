import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense.dart';
import '../models/category.dart';

/// Exports the current user's data for GDPR portability (art. 20.º).
///
/// Collects `expenses`, `categories`, `subscriptions`, `report_preferences`
/// and `monthly_status` from Supabase and builds a JSON or CSV file that is
/// then shared via the OS share sheet.
class ExportService {
  final SupabaseClient _client;

  ExportService(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Fetches all data for the current user in this app.
  Future<Map<String, dynamic>> fetchAllData() async {
    final categories = await _client
        .from('categories')
        .select()
        .eq('app_name', 'expenses')
        .eq('user_id', _userId)
        .order('sort_order');

    // `expenses` has no app_name column — filter through the user's
    // categories for this app (same approach as send-monthly-report).
    final catIds = (categories as List).map((c) => c['id']).toList();
    var expensesQuery = _client
        .from('expenses')
        .select('*, categories(name, icon_name, color_hex)')
        .eq('user_id', _userId);
    if (catIds.isNotEmpty) {
      expensesQuery = expensesQuery.inFilter('category_id', catIds);
    } else {
      expensesQuery = expensesQuery.eq('category_id', '00000000-0000-0000-0000-000000000000');
    }
    final expenses = await expensesQuery.order('created_at', ascending: false);

    final subscriptions = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', _userId)
        .eq('app_name', 'expenses');

    final reportPrefs = await _client
        .from('report_preferences')
        .select()
        .eq('user_id', _userId)
        .eq('app_name', 'expenses');

    final monthlyStatus = await _client
        .from('monthly_status')
        .select()
        .eq('user_id', _userId)
        .order('expense_month', ascending: true);

    return {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'app_name': 'expenses',
      'user_id': _userId,
      'expenses': expenses,
      'categories': categories,
      'subscriptions': subscriptions,
      'report_preferences': reportPrefs,
      'monthly_status': monthlyStatus,
    };
  }

  /// Builds a JSON string containing all the user's data.
  Future<String> buildJson() async {
    final data = await fetchAllData();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Builds a CSV string containing expenses + categories.
  Future<String> buildCsv() async {
    final data = await fetchAllData();

    final expenses = (data['expenses'] as List)
        .map((json) => Expense.fromJson(json))
        .toList();

    final categories = (data['categories'] as List)
        .map((json) => Category.fromJson(json))
        .toList();

    final rows = <List<dynamic>>[
      ['Nome', 'Valor', 'Categoria', 'Tipo', 'Data de Criação'],
      ...expenses.map(
        (e) => [
          e.name,
          e.amount.toStringAsFixed(2),
          e.categoryName ?? '',
          e.type == 'recurring' ? 'Recorrente' : 'Único',
          '${e.createdAt.day.toString().padLeft(2, '0')}/${e.createdAt.month.toString().padLeft(2, '0')}/${e.createdAt.year}',
        ],
      ),
    ];

    // Add a blank separator row, then categories
    rows.add([]);
    rows.add(['# Categorias']);
    rows.add(['Nome', 'Ícone', 'Cor', 'Ordem']);
    rows.addAll(
      categories.map(
        (c) => [c.name, c.iconName, c.colorHex, c.sortOrder.toString()],
      ),
    );

    return const CsvEncoder().convert(rows);
  }

  /// Writes [content] to a temp file and shares it via the share sheet.
  Future<void> shareFile({
    required String filename,
    required String content,
    String mimeType = 'application/json',
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        text: 'Export PocketExpenses',
      ),
    );
  }
}
