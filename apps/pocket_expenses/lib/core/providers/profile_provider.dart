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

final settingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.read(profileServiceProvider);
  return service.getSettings();
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

  Future<void> updateCurrency(String currency) async {
    await _service.updateSettings(currency: currency);
    _ref.invalidate(settingsProvider);
  }

  Future<void> updateBudget(double? budget) async {
    await _service.updateSettings(monthlyBudget: budget);
    _ref.invalidate(settingsProvider);
  }

  Future<void> updateNotifications(bool enabled) async {
    await _service.updateSettings(notificationsEnabled: enabled);
    _ref.invalidate(settingsProvider);
  }
}
