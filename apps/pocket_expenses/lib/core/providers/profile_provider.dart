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

class ProfileFlags {
  final bool onboardingCompleted;
  final bool wizardFreeUsed;

  const ProfileFlags({
    this.onboardingCompleted = false,
    this.wizardFreeUsed = false,
  });
}

final profileFlagsProvider = FutureProvider<ProfileFlags>((ref) async {
  final client = ref.read(supabaseClientProvider);
  if (client.auth.currentUser == null) return const ProfileFlags();
  try {
    final data = await client
        .from('profiles')
        .select('onboarding_completed, wizard_free_used')
        .eq('id', client.auth.currentUser!.id)
        .maybeSingle();
    if (data == null) return const ProfileFlags();
    return ProfileFlags(
      onboardingCompleted: data['onboarding_completed'] as bool? ?? false,
      wizardFreeUsed: data['wizard_free_used'] as bool? ?? false,
    );
  } catch (_) {
    return const ProfileFlags();
  }
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

  Future<void> completeOnboarding() async {
    await _service.updateFlags({'onboarding_completed': true});
    _ref.invalidate(profileFlagsProvider);
  }

  Future<void> markWizardFreeUsed() async {
    await _service.updateFlags({'wizard_free_used': true});
    _ref.invalidate(profileFlagsProvider);
  }
}
