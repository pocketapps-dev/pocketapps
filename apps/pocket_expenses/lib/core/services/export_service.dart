import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/expense.dart';

class ExportService {
  final SupabaseClient _client;

  ExportService(this._client);

  Future<void> exportExpensesAsCsv() async {
    final userId = _client.auth.currentUser!.id;

    final response = await _client
        .from('expenses')
        .select('*, categories(name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final expenses = (response as List)
        .map((json) => Expense.fromJson(json))
        .toList();

    final rows = <List<dynamic>>[
      ['Nome', 'Valor', 'Categoria', 'Tipo', 'Data de Criação'],
      ...expenses.map((e) => [
            e.name,
            e.amount.toStringAsFixed(2),
            e.categoryName ?? '',
            e.type == 'recurring' ? 'Recorrente' : 'Único',
            '${e.createdAt.day.toString().padLeft(2, '0')}/${e.createdAt.month.toString().padLeft(2, '0')}/${e.createdAt.year}',
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/pocketexpenses_export.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(file.path)], text: 'Export PocketExpenses');
  }
}
