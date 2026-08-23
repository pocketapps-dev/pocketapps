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

  Future<void> updateFlags(Map<String, dynamic> flags) async {
    await _client.from('profiles').update(flags).eq('id', _userId);
  }

  Future<bool> checkUsernameAvailable(String username) async {
    final result = await _client.rpc(
      'check_username_available',
      params: {'p_username': username.toLowerCase()},
    );
    return result as bool;
  }
}
