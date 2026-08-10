import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _client;

  ReportService(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<Map<String, dynamic>?> getPreferences({String appName = 'expenses'}) async {
    final response = await _client
        .from('report_preferences')
        .select()
        .eq('user_id', _userId)
        .eq('app_name', appName)
        .maybeSingle();
    return response;
  }

  Future<void> savePreferences({
    required bool emailReportsEnabled,
    int? reportDay,
    int? reportHour,
    bool includeCategories = true,
    bool includeCharts = true,
    String reportType = 'detailed',
  }) async {
    await _client.from('report_preferences').upsert(
      {
        'user_id': _userId,
        'app_name': 'expenses',
        'email_reports_enabled': emailReportsEnabled,
        'report_day': ?reportDay,
        'report_hour': ?reportHour,
        'include_categories': includeCategories,
        'include_charts': includeCharts,
        'report_type': reportType,
      },
      onConflict: 'user_id,app_name',
    );
  }

  Future<bool> sendTestReport({String? reportType, String? month}) async {
    try {
      await _client.functions.invoke(
        'send-monthly-report',
        body: {
          'test': true,
          'report_type': ?reportType,
          'month': ?month,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
