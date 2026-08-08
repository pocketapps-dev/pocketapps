import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/currency_provider.dart';
import '../../core/models/category.dart';
import '../../core/models/expense.dart';
import '../../core/models/monthly_status.dart';
import '../../core/models/subscription.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/expense_provider.dart';
import '../../core/providers/subscription_provider.dart';

class DashboardTab extends ConsumerStatefulWidget {
  final VoidCallback onRefresh;
  const DashboardTab({super.key, required this.onRefresh});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  late DateTime _selectedMonth;

  static const _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(categoryActionsProvider).ensureDefaultCategories();
    });
  }

  bool get _canGoBack {
    final now = DateTime.now();
    final current = now.year * 12 + now.month;
    final selected = _selectedMonth.year * 12 + _selectedMonth.month;
    return current - selected < 6;
  }

  bool get _canGoForward {
    final now = DateTime.now();
    final current = now.year * 12 + now.month;
    final selected = _selectedMonth.year * 12 + _selectedMonth.month;
    return selected - current < 6;
  }

  void _previousMonth() {
    if (!_canGoBack) return;
    setState(
      () => _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      ),
    );
  }

  void _nextMonth() {
    if (!_canGoForward) return;
    setState(
      () => _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
      ),
    );
  }

  String get _monthLabel =>
      '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider(true));
    final statusesAsync = ref.watch(monthlyStatusesProvider(_selectedMonth));
    final categoriesAsync = ref.watch(categoriesProvider('expenses'));
    final subscription = ref.watch(subscriptionProvider).value;
    final currencyFormat = currencyFormatFor(ref.watch(currencyProvider));

    return SafeArea(
      child: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (expenses) => statusesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (statuses) => categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (categories) => _buildDashboard(
              context,
              expenses,
              statuses,
              categories,
              currencyFormat,
              subscription,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    List<Expense> expenses,
    Map<String, MonthlyStatus> statuses,
    List<Category> categories,
    NumberFormat currencyFormat,
    Subscription? subscription,
  ) {
    final activeExpenses = expenses
        .where((e) => statuses[e.id]?.isSkipped != true)
        .toList();
    final grandTotal = activeExpenses.fold<double>(0, (s, e) => s + e.amount);
    final paidTotal = activeExpenses
        .where((e) => statuses[e.id]?.isPaid == true)
        .fold<double>(0, (s, e) => s + e.amount);
    final unpaidTotal = grandTotal - paidTotal;
    final paidCount = activeExpenses
        .where((e) => statuses[e.id]?.isPaid == true)
        .length;

    final byCategory = <String, double>{};
    final catColorMap = <String, String>{};
    for (final cat in categories) {
      catColorMap[cat.name] = cat.colorHex;
    }
    for (final e in expenses) {
      final status = statuses[e.id];
      if (status?.isSkipped == true) continue;
      final catName = e.categoryName ?? 'Sem categoria';
      byCategory[catName] = (byCategory[catName] ?? 0) + e.amount;
    }
    final sortedCats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final upcoming =
        expenses.where((e) {
          final status = statuses[e.id];
          if (status?.isPaid == true || status?.isSkipped == true) return false;
          if (e.type == 'unique' && e.startDate != null) {
            final diff = DateTime(
              e.startDate!.year,
              e.startDate!.month,
              e.startDate!.day,
            ).difference(todayDate).inDays;
            return diff >= 0 && diff <= 7;
          }
          if (e.dueDay == null) return false;
          final effectiveDay = _effectiveDueDay(
            e,
            _selectedMonth.month,
            _selectedMonth.year,
          );
          final dueDate = DateTime(
            _selectedMonth.year,
            _selectedMonth.month,
            effectiveDay,
          );
          final diff = dueDate.difference(todayDate).inDays;
          return diff >= 0 && diff <= 7;
        }).toList()..sort((a, b) {
          final aDay = _effectiveDueDay(
            a,
            _selectedMonth.month,
            _selectedMonth.year,
          );
          final bDay = _effectiveDueDay(
            b,
            _selectedMonth.month,
            _selectedMonth.year,
          );
          return aDay.compareTo(bDay);
        });

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.receipt_long,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PocketExpenses',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.chevron_left,
                          color: _canGoBack
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                        onPressed: _canGoBack ? _previousMonth : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        _monthLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: _canGoForward
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                        onPressed: _canGoForward ? _nextMonth : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PlanBanner(subscription: subscription),
        const SizedBox(height: 20),
        if (expenses.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Sem despas para $_monthLabel',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              ),
            ),
          )
        else ...[
          Row(
            children: [
              _SummaryCard(
                title: 'Total',
                value: currencyFormat.format(grandTotal),
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                title: 'Pago',
                value: currencyFormat.format(paidTotal),
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                title: 'Pendente',
                value: currencyFormat.format(unpaidTotal),
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: grandTotal > 0 ? paidTotal / grandTotal : 0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Colors.green),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$paidCount/${activeExpenses.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (upcoming.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Proximos 7 dias',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${upcoming.length} pendentes',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...upcoming.map((e) {
              final effectiveDay = _effectiveDueDay(
                e,
                _selectedMonth.month,
                _selectedMonth.year,
              );
              final diff = DateTime(
                _selectedMonth.year,
                _selectedMonth.month,
                effectiveDay,
              ).difference(todayDate).inDays;
              final label = diff == 0
                  ? 'Hoje'
                  : diff == 1
                  ? 'Amanha'
                  : 'Em $diff dias';

              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: _catColor(e, categories),
                    child: Icon(
                      _catIcon(e, categories),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    e.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    label,
                    style: TextStyle(
                      color: diff <= 1 ? Colors.red : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Text(
                    currencyFormat.format(e.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          Text(
            'Por Categoria',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: sortedCats.map((entry) {
                  final pct = grandTotal > 0
                      ? (entry.value / grandTotal * 100)
                      : 0.0;
                  return PieChartSectionData(
                    value: entry.value,
                    color: _catColorHex(entry.key, catColorMap),
                    radius: 50,
                    title: '${pct.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...sortedCats.map((entry) {
            final pct = grandTotal > 0 ? entry.value / grandTotal : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.category,
                    color: _catColorHex(entry.key, catColorMap),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              currencyFormat.format(entry.value),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            _catColorHex(entry.key, catColorMap),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  int _effectiveDueDay(Expense e, int month, int year) {
    final day = e.dueDay ?? 1;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return day > daysInMonth ? daysInMonth : day;
  }

  Color _catColor(Expense e, List<Category> categories) {
    for (final c in categories) {
      if (c.id == e.categoryId) {
        return Color(
          int.parse('FF${c.colorHex.replaceAll('#', '')}', radix: 16),
        );
      }
    }
    return Colors.grey;
  }

  IconData _catIcon(Expense e, List<Category> categories) {
    for (final c in categories) {
      if (c.id == e.categoryId) return _getIconData(c.iconName);
    }
    return Icons.category;
  }

  Color _catColorHex(String catName, Map<String, String> catColorMap) {
    final hex = catColorMap[catName];
    if (hex != null) {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    }
    return Colors.grey;
  }

  IconData _getIconData(String iconName) {
    const iconMap = <String, IconData>{
      'home': Icons.home,
      'bolt': Icons.bolt,
      'water_drop': Icons.water_drop,
      'local_fire_department': Icons.local_fire_department,
      'directions_car': Icons.directions_car,
      'subscriptions': Icons.subscriptions,
      'account_balance': Icons.account_balance,
      'favorite': Icons.favorite,
      'shopping_cart': Icons.shopping_cart,
      'restaurant': Icons.restaurant,
      'sports_esports': Icons.sports_esports,
      'school': Icons.school,
      'phone': Icons.phone,
      'shield': Icons.shield,
      'checkroom': Icons.checkroom,
      'category': Icons.category,
    };
    return iconMap[iconName] ?? Icons.category;
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanBanner extends StatelessWidget {
  final Subscription? subscription;

  const _PlanBanner({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final isPremium = subscription?.isActive == true;
    final planName = subscription?.displayName ?? 'Free';

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/settings/plans'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isPremium
                    ? Colors.amber.shade100
                    : Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                child: Icon(
                  isPremium ? Icons.workspace_premium : Icons.person_outline,
                  size: 20,
                  color: isPremium
                      ? Colors.amber.shade800
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium ? 'PocketExpenses $planName' : 'Plano Free',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPremium
                          ? 'Ativo até ${_formatDate(subscription?.endsAt)}'
                          : 'Faz upgrade para Premium · €14.99/ano',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'indeterminado';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
