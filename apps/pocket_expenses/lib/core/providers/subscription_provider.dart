import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription.dart';
import '../services/subscription_service.dart';
import 'dev_mode_provider.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(Supabase.instance.client);
});

final subscriptionProvider = FutureProvider<Subscription?>((ref) async {
  // Modo de teste: simula o estado da subscricao sem tocar na base de dados.
  final override = ref.watch(subscriptionOverrideProvider);
  switch (override) {
    case SubscriptionOverride.premium:
      return const Subscription(
        id: 'test-premium',
        plan: 'premium',
        status: 'active',
      );
    case SubscriptionOverride.free:
      return const Subscription(
        id: 'test-free',
        plan: 'free',
        status: 'active',
      );
    case SubscriptionOverride.real:
      break;
  }

  final service = ref.watch(subscriptionServiceProvider);
  return service.getSubscription();
});

final founderCountProvider = FutureProvider<int>((ref) async {
  final client = Supabase.instance.client;
  try {
    final data = await client.rpc('get_founder_count');
    return data is int ? data : 0;
  } catch (_) {
    return 0;
  }
});

final subscriptionActionsProvider = Provider<SubscriptionActions>((ref) {
  return SubscriptionActions(ref);
});

class SubscriptionActions {
  final Ref _ref;

  SubscriptionActions(this._ref);

  SubscriptionService get _service => _ref.read(subscriptionServiceProvider);

  Future<String> redeem(String code) async {
    try {
      final result = await _service.redeemActivationCode(code);
      if (result.success) {
        _ref.invalidate(subscriptionProvider);
      }
      return result.message;
    } catch (_) {
      return 'Erro ao ativar o código';
    }
  }
}
