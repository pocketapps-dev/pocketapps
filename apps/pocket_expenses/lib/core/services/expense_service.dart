import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense.dart';
import '../models/monthly_status.dart';

class ExpenseService {
  final SupabaseClient _client;

  ExpenseService(this._client);

  Future<List<Expense>> getExpenses({
    required String userId,
    bool? isActive,
  }) async {
    var query = _client
        .from('expenses')
        .select('*, categories(name, icon_name, color_hex)')
        .eq('user_id', userId);

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((json) => Expense.fromJson(json))
        .toList();
  }

  Future<Expense> getExpense(String id) async {
    final response = await _client
        .from('expenses')
        .select('*, categories(name, icon_name, color_hex)')
        .eq('id', id)
        .single();

    return Expense.fromJson(response);
  }

  Future<void> seedSampleExpenses(Map<String, String> categoryIdByName) async {
    final userId = _client.auth.currentUser!.id;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final samples = [
      {
        'user_id': userId,
        'category_id': categoryIdByName['Habitação'],
        'name': 'Renda',
        'amount': 650,
        'type': 'recurring',
        'is_variable': false,
        'due_day': 1,
        'start_date': monthStart.toIso8601String().split('T')[0],
        'is_active': true,
        'reminder_days': 3,
      },
      {
        'user_id': userId,
        'category_id': categoryIdByName['Veículo'],
        'name': 'Seguro Auto',
        'amount': 45.50,
        'type': 'recurring',
        'is_variable': false,
        'due_day': 15,
        'start_date': monthStart.toIso8601String().split('T')[0],
        'is_active': true,
        'reminder_days': 5,
      },
      {
        'user_id': userId,
        'category_id': categoryIdByName['Crédito'],
        'name': 'Cartão Crédito',
        'amount': 150,
        'type': 'recurring',
        'is_variable': true,
        'due_day': 10,
        'start_date': monthStart.toIso8601String().split('T')[0],
        'is_active': true,
        'reminder_days': 3,
      },
      {
        'user_id': userId,
        'category_id': categoryIdByName['Subscrições'],
        'name': 'Streaming',
        'amount': 11.99,
        'type': 'recurring',
        'is_variable': false,
        'due_day': 5,
        'start_date': monthStart.toIso8601String().split('T')[0],
        'is_active': true,
        'reminder_days': 2,
      },
    ];

    for (final sample in samples) {
      await _client.from('expenses').insert(sample);
    }
  }

  Future<Expense> createExpense(Expense expense) async {
    final response = await _client
        .from('expenses')
        .insert(expense.toJson())
        .select('*, categories(name, icon_name, color_hex)')
        .single();

    return Expense.fromJson(response);
  }

  Future<Expense> updateExpense(Expense expense) async {
    final response = await _client
        .from('expenses')
        .update(expense.toJson())
        .eq('id', expense.id)
        .select('*, categories(name, icon_name, color_hex)')
        .single();

    return Expense.fromJson(response);
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }

  // Monthly Status
  Future<MonthlyStatus?> getMonthlyStatus({
    required String expenseId,
    required DateTime month,
  }) async {
    final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
    final response = await _client
        .from('monthly_status')
        .select()
        .eq('expense_id', expenseId)
        .eq('expense_month', monthStr)
        .maybeSingle();

    return response != null ? MonthlyStatus.fromJson(response) : null;
  }

  Future<Map<String, MonthlyStatus>> getMonthlyStatuses({
    required String userId,
    required DateTime month,
  }) async {
    final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
    final response = await _client
        .from('monthly_status')
        .select()
        .eq('user_id', userId)
        .eq('expense_month', monthStr);

    final map = <String, MonthlyStatus>{};
    for (final json in response as List) {
      final status = MonthlyStatus.fromJson(json);
      map[status.expenseId] = status;
    }
    return map;
  }

  Future<void> togglePaid({
    required String expenseId,
    required DateTime month,
  }) async {
    await _client.rpc('toggle_expense_paid', params: {
      'p_expense_id': expenseId,
      'p_month': '${month.year}-${month.month.toString().padLeft(2, '0')}-01',
    });
  }

  Future<void> toggleSkip({
    required String expenseId,
    required DateTime month,
  }) async {
    await _client.rpc('toggle_expense_skip', params: {
      'p_expense_id': expenseId,
      'p_month': '${month.year}-${month.month.toString().padLeft(2, '0')}-01',
    });
  }
}
