import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense.dart';
import '../models/monthly_status.dart';
import '../services/expense_service.dart';

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService(Supabase.instance.client);
});

final expensesProvider =
    FutureProvider.family<List<Expense>, bool?>((ref, isActive) async {
  final service = ref.watch(expenseServiceProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  return service.getExpenses(userId: userId, isActive: isActive);
});

final monthlyStatusesProvider =
    FutureProvider.family<Map<String, MonthlyStatus>, DateTime>(
  (ref, month) async {
    final service = ref.watch(expenseServiceProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return {};
    return service.getMonthlyStatuses(userId: userId, month: month);
  },
);

class ExpenseActions {
  final ExpenseService _service;

  ExpenseActions(this._service);

  Future<void> create(Expense expense) async {
    await _service.createExpense(expense);
  }

  Future<void> update(Expense expense) async {
    await _service.updateExpense(expense);
  }

  Future<void> delete(String id) async {
    await _service.deleteExpense(id);
  }

  Future<void> togglePaid(String expenseId, DateTime month) async {
    await _service.togglePaid(expenseId: expenseId, month: month);
  }

  Future<void> toggleSkip(String expenseId, DateTime month) async {
    await _service.toggleSkip(expenseId: expenseId, month: month);
  }
}

final expenseActionsProvider = Provider<ExpenseActions>((ref) {
  return ExpenseActions(ref.watch(expenseServiceProvider));
});
