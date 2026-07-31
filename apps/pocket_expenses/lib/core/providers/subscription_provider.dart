import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription.dart';
import '../services/subscription_service.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(Supabase.instance.client);
});

final subscriptionProvider = FutureProvider<Subscription?>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return service.getSubscription();
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
