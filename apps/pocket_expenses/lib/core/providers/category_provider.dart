import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import 'expense_provider.dart';

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService(Supabase.instance.client);
});

final categoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  appName,
) async {
  final service = ref.watch(categoryServiceProvider);
  final cats = await service.getCategories(appName: appName);
  final sorted = [...cats];
  sorted.sort((a, b) {
    if (a.name == 'Sem Categoria') return 1;
    if (b.name == 'Sem Categoria') return -1;
    return a.sortOrder.compareTo(b.sortOrder);
  });
  return sorted;
});

final categoryActionsProvider = Provider<CategoryActions>((ref) {
  return CategoryActions(ref);
});

class CategoryActions {
  final Ref _ref;

  CategoryActions(this._ref);

  CategoryService get _service => _ref.read(categoryServiceProvider);

  Future<Category> create({
    required String name,
    required String iconName,
    required String colorHex,
    double? budget,
  }) async {
    final category = await _service.createCategory(
      name: name,
      iconName: iconName,
      colorHex: colorHex,
      budget: budget,
    );
    _ref.invalidate(categoriesProvider);
    return category;
  }

  Future<void> update({
    required String id,
    required String name,
    required String iconName,
    required String colorHex,
    double? budget,
  }) async {
    await _service.updateCategory(
      id: id,
      name: name,
      iconName: iconName,
      colorHex: colorHex,
      budget: budget,
    );
    _ref.invalidate(categoriesProvider);
  }

  Future<void> delete(String id) async {
    final uncategorized = await _service.findOrCreateUncategorized();
    if (uncategorized != null && uncategorized.id != id) {
      await _service.reassignExpensesToCategory(fromId: id, toId: uncategorized.id);
    }
    await _service.deleteCategory(id);
    _ref.invalidate(categoriesProvider);
    _ref.invalidate(expensesProvider);
  }

  Future<void> reorder(List<String> orderedIds) async {
    await _service.reorderCategories(orderedIds);
    _ref.invalidate(categoriesProvider);
  }

  Future<void> ensureDefaultCategories() async {
    final existing = await _service.getCategories();
    if (existing.isNotEmpty) return;

    final categories = await _service.seedDefaultCategories();
    _ref.invalidate(categoriesProvider);

    final categoryIdByName = {for (final cat in categories) cat.name: cat.id};
    final expenseService = _ref.read(expenseServiceProvider);
    await expenseService.seedSampleExpenses(categoryIdByName);
    _ref.invalidate(expensesProvider);
  }
}
