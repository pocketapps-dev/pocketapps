import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const devModePrefKey = 'dev_mode_enabled';
const subscriptionOverridePrefKey = 'subscription_override';

enum SubscriptionOverride { real, free, premium }

SubscriptionOverride subscriptionOverrideFromName(String? name) {
  switch (name) {
    case 'free':
      return SubscriptionOverride.free;
    case 'premium':
      return SubscriptionOverride.premium;
    default:
      return SubscriptionOverride.real;
  }
}

class DevModeNotifier extends Notifier<bool> {
  DevModeNotifier({this.initial = false});

  final bool initial;

  @override
  bool build() => initial;

  Future<void> setEnabled(bool value) async {
    state = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(devModePrefKey, value);
  }
}

final devModeProvider = NotifierProvider<DevModeNotifier, bool>(
  DevModeNotifier.new,
);

class SubscriptionOverrideNotifier extends Notifier<SubscriptionOverride> {
  SubscriptionOverrideNotifier({
    this.initial = SubscriptionOverride.real,
  });

  final SubscriptionOverride initial;

  @override
  SubscriptionOverride build() => initial;

  Future<void> setOverride(SubscriptionOverride value) async {
    state = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(subscriptionOverridePrefKey, value.name);
  }
}

final subscriptionOverrideProvider =
    NotifierProvider<SubscriptionOverrideNotifier, SubscriptionOverride>(
  SubscriptionOverrideNotifier.new,
);
