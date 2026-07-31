import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';

import '../services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.read(supabaseClientProvider));
});

final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.read(profileServiceProvider);
  return service.getProfile();
});

final profileActionsProvider = Provider<ProfileActions>((ref) {
  return ProfileActions(ref);
});

class ProfileActions {
  final Ref _ref;

  ProfileActions(this._ref);

  ProfileService get _service => _ref.read(profileServiceProvider);

  Future<bool> updateUsername(String username) async {
    try {
      final available = await _service.checkUsernameAvailable(username);
      if (!available) return false;
      await _service.updateUsername(username);
      _ref.invalidate(profileProvider);
      return true;
    } catch (_) {
      return false;
    }
  }
}
