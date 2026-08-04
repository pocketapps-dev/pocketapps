import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/theme_info.dart';

class ThemeStoreService {
  final SupabaseClient _client;

  ThemeStoreService(this._client);

  Future<List<ThemeInfo>> getThemes({String appName = 'expenses'}) async {
    final response = await _client.rpc(
      'get_user_themes',
      params: {'p_app_name': appName},
    );

    if (response is! List) return [];
    final themes = response
        .map((e) => ThemeInfo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    themes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return themes;
  }

  Future<String> redeemThemeCode(
    String code, {
    String appName = 'expenses',
  }) async {
    final response = await _client.rpc(
      'validate_theme_activation_code',
      params: {'p_code': code.trim(), 'p_app_name': appName},
    );

    final data = response is String
        ? jsonDecode(response) as Map<String, dynamic>
        : (response as Map<String, dynamic>);

    final valid = data['valid'] == true;
    if (!valid) {
      return data['error'] as String? ?? 'Código inválido';
    }
    final themeName = data['theme_name'] as String? ?? 'Tema';
    return 'Tema "$themeName" ativado com sucesso!';
  }
}
