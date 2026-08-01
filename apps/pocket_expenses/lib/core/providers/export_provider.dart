import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/export_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(Supabase.instance.client);
});

/// Actions for exporting the user's data (GDPR portability).
final exportActionsProvider = Provider<ExportActions>((ref) {
  return ExportActions(ref);
});

class ExportActions {
  final Ref _ref;

  ExportActions(this._ref);

  ExportService get _service => _ref.read(exportServiceProvider);

  /// Exports all data as a JSON file and shares it.
  Future<void> exportJson() async {
    final json = await _service.buildJson();
    await _service.shareFile(
      filename: 'pocketexpenses_export.json',
      content: json,
      mimeType: 'application/json',
    );
  }

  /// Exports expenses + categories as a CSV file and shares it.
  Future<void> exportCsv() async {
    final csv = await _service.buildCsv();
    await _service.shareFile(
      filename: 'pocketexpenses_export.csv',
      content: csv,
      mimeType: 'text/csv',
    );
  }
}
