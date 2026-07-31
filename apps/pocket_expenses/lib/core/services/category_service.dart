import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';

class CategoryService {
  final SupabaseClient _client;

  CategoryService(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<List<Category>> getCategories({String appName = 'expenses'}) async {
    final response = await _client
        .from('categories')
        .select()
        .eq('app_name', appName)
        .eq('user_id', _userId)
        .order('sort_order');

    return (response as List)
        .map((json) => Category.fromJson(json))
        .toList();
  }

  Future<Category> getCategory(String id) async {
    final response = await _client
        .from('categories')
        .select()
        .eq('id', id)
        .single();

    return Category.fromJson(response);
  }

  Future<Category> createCategory({
    required String name,
    required String iconName,
    required String colorHex,
    String appName = 'expenses',
    int sortOrder = 0,
    double? budget,
    bool isDefault = false,
  }) async {
    final maxOrder = await _client
        .from('categories')
        .select('sort_order')
        .eq('app_name', appName)
        .eq('user_id', _userId)
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();

    final nextOrder = (maxOrder?['sort_order'] as int? ?? 0) + 1;

    final response = await _client
        .from('categories')
        .insert({
          'app_name': appName,
          'name': name,
          'icon_name': iconName,
          'color_hex': colorHex,
          'sort_order': sortOrder > 0 ? sortOrder : nextOrder,
          'budget': budget,
          'is_default': isDefault,
          'user_id': _userId,
        })
        .select()
        .single();

    return Category.fromJson(response);
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String iconName,
    required String colorHex,
    double? budget,
  }) async {
    await _client.from('categories').update({
      'name': name,
      'icon_name': iconName,
      'color_hex': colorHex,
      'budget': budget,
    }).eq('id', id);
  }

  Future<void> reassignExpensesToCategory({required String fromId, required String toId}) async {
    await _client
        .from('expenses')
        .update({'category_id': toId})
        .eq('category_id', fromId)
        .eq('user_id', _userId);
  }

  Future<void> deleteCategory(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }

  Future<Category?> findOrCreateUncategorized() async {
    final existing = await _client
        .from('categories')
        .select()
        .eq('name', 'Sem Categoria')
        .eq('user_id', _userId)
        .maybeSingle();

    if (existing != null) return Category.fromJson(existing);

    final maxOrder = await _client
        .from('categories')
        .select('sort_order')
        .eq('app_name', 'expenses')
        .eq('user_id', _userId)
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();

    final nextOrder = (maxOrder?['sort_order'] as int? ?? 0) + 1;

    final response = await _client
        .from('categories')
        .insert({
          'app_name': 'expenses',
          'name': 'Sem Categoria',
          'icon_name': 'category',
          'color_hex': '#94A3B8',
          'sort_order': nextOrder,
          'is_default': true,
          'user_id': _userId,
        })
        .select()
        .single();

    return Category.fromJson(response);
  }

  Future<void> reorderCategories(List<String> orderedIds) async {
    final semCategoria = await _client
        .from('categories')
        .select('id')
        .eq('name', 'Sem Categoria')
        .eq('user_id', _userId)
        .maybeSingle();

    final uncatId = semCategoria?['id'] as String?;

    final filtered = <String>[];
    for (final id in orderedIds) {
      if (id == uncatId) continue;
      filtered.add(id);
    }
    if (uncatId != null) filtered.add(uncatId);

    await Future.wait(
      filtered.asMap().entries.map((entry) {
        return _client
            .from('categories')
            .update({'sort_order': entry.key + 1})
            .eq('id', entry.value)
            .eq('user_id', _userId);
      }),
    );
  }

  Future<List<Category>> seedDefaultCategories() async {
    final defaultCategories = [
      (name: 'Habitação', icon: 'home', color: '#EF4444'),
      (name: 'Veículo', icon: 'directions_car', color: '#3B82F6'),
      (name: 'Crédito', icon: 'credit_card', color: '#F59E0B'),
      (name: 'Subscrições', icon: 'subscriptions', color: '#6366F1'),
      (name: 'Sem Categoria', icon: 'category', color: '#94A3B8'),
    ];

    final results = <Category>[];
    for (var i = 0; i < defaultCategories.length; i++) {
      final cat = defaultCategories[i];
      final result = await createCategory(
        name: cat.name,
        iconName: cat.icon,
        colorHex: cat.color,
        sortOrder: i + 1,
        isDefault: true,
      );
      results.add(result);
    }
    return results;
  }
}
