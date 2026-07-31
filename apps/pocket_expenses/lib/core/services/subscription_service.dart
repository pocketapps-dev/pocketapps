import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription.dart';

class SubscriptionService {
  final SupabaseClient _client;

  SubscriptionService(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<Subscription?> getSubscription({String appName = 'expenses'}) async {
    final response = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', _userId)
        .eq('app_name', appName)
        .maybeSingle();

    if (response == null) return null;
    return Subscription.fromJson(response);
  }

  Future<ActivationResult> redeemActivationCode(String code) async {
    final response = await _client.rpc(
      'validate_activation_code',
      params: {'p_code': code.trim(), 'p_app_name': 'expenses'},
    );

    final data = response is String
        ? jsonDecode(response) as Map<String, dynamic>
        : (response as Map<String, dynamic>);

    final valid = data['valid'] == true;
    if (!valid) {
      return ActivationResult(
        success: false,
        message: data['error'] as String? ?? 'Código inválido',
      );
    }
    return const ActivationResult(success: true, message: 'Premium ativado com sucesso!');
  }
}

class ActivationResult {
  final bool success;
  final String message;

  const ActivationResult({required this.success, required this.message});
}
