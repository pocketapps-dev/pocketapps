import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return PocketAuth.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

class _RecoveryNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void trigger() => state = true;

  void reset() => state = false;
}

final isRecoveryFlowProvider = NotifierProvider<_RecoveryNotifier, bool>(
  _RecoveryNotifier.new,
);
