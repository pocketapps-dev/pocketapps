import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class BackupSnapshot {
  final String fileName;
  final int sizeBytes;

  BackupSnapshot({required this.fileName, required this.sizeBytes});
}

class BackupRestoreResult {
  final int categories;
  final int expenses;
  final int monthlyStatuses;

  BackupRestoreResult({
    required this.categories,
    required this.expenses,
    required this.monthlyStatuses,
  });
}

class BackupService {
  final SupabaseClient _client;

  BackupService(this._client);

  static const _bucket = 'backups';

  String get _userId => _client.auth.currentUser!.id;

  Future<List<BackupSnapshot>> listSnapshots() async {
    final files = await _client.storage.from(_bucket).list(path: _userId);
    return files
        .where((f) => f.name.endsWith('.json'))
        .map(
          (f) => BackupSnapshot(
            fileName: f.name,
            sizeBytes: (f.metadata?['size'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.fileName.compareTo(a.fileName));
  }

  Future<String> createBackupNow() async {
    final res = await _client.functions.invoke('create-daily-backups');
    final data = res.data;
    if (data is Map && data['snapshot'] is String) {
      return data['snapshot'] as String;
    }
    throw Exception('Resposta inesperada do servidor');
  }

  Future<BackupRestoreResult> restore(String fileName) async {
    final Uint8List bytes =
        await _client.storage.from(_bucket).download('$_userId/$fileName');
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> || decoded['data'] is! Map) {
      throw Exception('Snapshot inválido');
    }
    final data = decoded['data'] as Map;

    List<Map<String, dynamic>> rows(dynamic raw) =>
        ((raw as List?) ?? const [])
            .whereType<Map>()
            .map((r) => {...r.cast<String, dynamic>(), 'user_id': _userId})
            .toList();

    final categories = rows(data['categories']);
    final expenses = rows(data['expenses']);
    final monthlyStatuses = rows(data['monthly_status']);

    if (categories.isNotEmpty) {
      await _client.from('categories').upsert(categories, onConflict: 'id');
    }
    if (expenses.isNotEmpty) {
      await _client.from('expenses').upsert(expenses, onConflict: 'id');
    }
    if (monthlyStatuses.isNotEmpty) {
      await _client
          .from('monthly_status')
          .upsert(monthlyStatuses, onConflict: 'id');
    }

    return BackupRestoreResult(
      categories: categories.length,
      expenses: expenses.length,
      monthlyStatuses: monthlyStatuses.length,
    );
  }
}
