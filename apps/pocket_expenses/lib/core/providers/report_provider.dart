import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/report_service.dart';

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService(Supabase.instance.client);
});

final reportPreferencesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(reportServiceProvider);
  final prefs = await service.getPreferences();
  return prefs ??
      {
        'email_reports_enabled': false,
        'report_day': 1,
        'report_hour': 9,
        'include_categories': true,
        'include_charts': true,
        'report_type': 'detailed',
      };
});

final reportActionsProvider = Provider<ReportActions>((ref) {
  return ReportActions(ref);
});

class ReportActions {
  final Ref _ref;

  ReportActions(this._ref);

  ReportService get _service => _ref.read(reportServiceProvider);

  Future<void> save({
    required bool emailReportsEnabled,
    int? reportDay,
    int? reportHour,
    bool includeCategories = true,
    bool includeCharts = true,
    String reportType = 'detailed',
  }) async {
    await _service.savePreferences(
      emailReportsEnabled: emailReportsEnabled,
      reportDay: reportDay,
      reportHour: reportHour,
      includeCategories: includeCategories,
      includeCharts: includeCharts,
      reportType: reportType,
    );
    _ref.invalidate(reportPreferencesProvider);
  }

  Future<bool> sendTest({String? reportType}) =>
      _service.sendTestReport(reportType: reportType);
}
