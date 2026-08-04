import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/theme_info.dart';
import '../services/theme_store_service.dart';

final themeStoreServiceProvider = Provider<ThemeStoreService>((ref) {
  return ThemeStoreService(Supabase.instance.client);
});

final themeStoreProvider = FutureProvider<List<ThemeInfo>>((ref) async {
  final service = ref.watch(themeStoreServiceProvider);
  return service.getThemes();
});

final themeStoreActionsProvider = Provider<ThemeStoreActions>((ref) {
  return ThemeStoreActions(ref);
});

class ThemeStoreActions {
  final Ref _ref;

  ThemeStoreActions(this._ref);

  ThemeStoreService get _service => _ref.read(themeStoreServiceProvider);

  Future<String> redeemThemeCode(String code) async {
    try {
      final message = await _service.redeemThemeCode(code);
      _ref.invalidate(themeStoreProvider);
      return message;
    } catch (_) {
      return 'Erro ao ativar o código';
    }
  }
}
