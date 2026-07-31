import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _client;

  ProfileService(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<Map<String, dynamic>?> getProfile() async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', _userId)
        .maybeSingle();
    return response;
  }

  Future<void> updateUsername(String username) async {
    await _client
        .from('profiles')
        .update({'username': username.toLowerCase()})
        .eq('id', _userId);
  }

  Future<Map<String, dynamic>> getSettings() async {
    final response = await _client
        .from('user_settings')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) {
      await _client.from('user_settings').insert({
        'user_id': _userId,
        'app_name': 'expenses',
      });
      return {'monthly_budget': null};
    }
    return response;
  }

  Future<void> updateSettings({
    double? monthlyBudget,
  }) async {
    final updates = <String, dynamic>{};
    if (monthlyBudget != null) updates['monthly_budget'] = monthlyBudget;

    if (updates.isNotEmpty) {
      await _client
          .from('user_settings')
          .upsert({'user_id': _userId, ...updates});
    }
  }

  Future<bool> checkUsernameAvailable(String username) async {
    final result = await _client.rpc(
      'check_username_available',
      params: {'p_username': username.toLowerCase()},
    );
    return result as bool;
  }
}
