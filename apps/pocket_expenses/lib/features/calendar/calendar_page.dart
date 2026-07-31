import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/currency_provider.dart';
import '../../core/models/category.dart';
import '../../core/models/expense.dart';
import '../../core/models/monthly_status.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/expense_provider.dart';
import '../expenses/expense_form_page.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _currentMonth;

  static const _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Marco',
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
    _currentMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() => setState(
    () => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1),
  );
  void _nextMonth() => setState(
    () => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1),
  );

  @override
  Widget build(BuildContext context) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;

    final expensesAsync = ref.watch(expensesProvider(true));
    final statusesAsync = ref.watch(monthlyStatusesProvider(_currentMonth));
    final categoriesAsync = ref.watch(categoriesProvider('expenses'));

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              'Calendario',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _prevMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${_monthNames[month - 1]} $year',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const _WeekdayHeader(),
          const SizedBox(height: 4),
          Expanded(
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (expenses) => statusesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro: $e')),
                data: (statuses) => categoriesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erro: $e')),
                  data: (categories) => _buildGrid(
                    year,
                    month,
                    daysInMonth,
                    firstWeekday,
                    expenses,
                    statuses,
                    categories,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _effectiveDueDay(Expense e, int month, int year) {
    final day = e.dueDay ?? 1;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return day > daysInMonth ? daysInMonth : day;
  }

  Color? _dayColor(List<_DayExpenses> dayExpenses, int month, int year) {
    if (dayExpenses.isEmpty) return null;
    final now = DateTime.now();
    final allPaid = dayExpenses.every((de) => de.isPaid);
    final allSkipped = dayExpenses.every((de) => de.isSkipped);
    if (allSkipped) return Colors.grey;
    if (allPaid) return Colors.green;
    final effectiveDay = dayExpenses.first.expense.dueDay ?? 1;
    final isPast = DateTime(
      year,
      month,
      effectiveDay,
    ).isBefore(DateTime(now.year, now.month, now.day));
    if (isPast) return Colors.red;
    return Colors.orange;
  }

  Widget _buildGrid(
    int year,
    int month,
    int daysInMonth,
    int firstWeekday,
    List<Expense> expenses,
    Map<String, MonthlyStatus> statuses,
    List<Category> categories,
  ) {
    final byDay = <int, List<_DayExpenses>>{};
    for (final e in expenses) {
      final effectiveDay = _effectiveDueDay(e, month, year);
      final status = statuses[e.id];
      byDay
          .putIfAbsent(effectiveDay, () => [])
          .add(
            _DayExpenses(
              expense: e,
              isPaid: status?.isPaid ?? false,
              isSkipped: status?.isSkipped ?? false,
            ),
          );
    }

    final catMap = <String, Category>{};
    for (final c in categories) {
      catMap[c.id] = c;
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.8,
      ),
      itemCount: (firstWeekday - 1) + daysInMonth,
      itemBuilder: (context, index) {
        final offset = firstWeekday - 1;
        if (index < offset) return const SizedBox();
        final day = index - offset + 1;
        final dayExpenses = byDay[day] ?? [];
        final isToday =
            day == DateTime.now().day &&
            month == DateTime.now().month &&
            year == DateTime.now().year;
        final color = _dayColor(dayExpenses, month, year);
        final hasAnyExpenses = dayExpenses.isNotEmpty;

        final activeExpenses = dayExpenses
            .where((de) => !de.isSkipped)
            .toList();
        final total = activeExpenses.fold<double>(
          0,
          (s, de) => s + de.expense.amount,
        );

        return GestureDetector(
          onTap: () =>
              _showDayExpenses(context, day, dayExpenses, month, year, catMap),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isToday
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.15)
                  : hasAnyExpenses && color != null
                  ? color.withValues(alpha: 0.15)
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isToday
                    ? Theme.of(context).colorScheme.primary
                    : hasAnyExpenses && color != null
                    ? color
                    : Colors.transparent,
                width: hasAnyExpenses || isToday ? 1.5 : 0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color: isToday
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                if (hasAnyExpenses) ...[
                  const SizedBox(height: 2),
                  if (activeExpenses.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${total.toStringAsFixed(0)}${currencyByCode(ref.watch(currencyProvider)).symbol}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDayExpenses(
    BuildContext context,
    int day,
    List<_DayExpenses> dayExpenses,
    int month,
    int year,
    Map<String, Category> catMap,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: dayExpenses.isEmpty ? 0.3 : 0.5,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dia $day',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExpenseFormPage(initialDueDay: day),
                      ),
                    );
                    if (result == true && mounted) setState(() {});
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Nova despesa',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (dayExpenses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Sem despesas neste dia.')),
              )
            else
              ...dayExpenses.map((de) {
                final e = de.expense;
                final cat = catMap[e.categoryId];
                final color = de.isSkipped
                    ? Colors.grey
                    : (de.isPaid ? Colors.green : Colors.orange);
                final currencyFormat = currencyFormatFor(ref.watch(currencyProvider));

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: de.isSkipped
                          ? Colors.grey
                          : _catColor(cat),
                      child: Icon(
                        _catIcon(cat),
                        color: de.isSkipped ? Colors.white : Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      e.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: de.isSkipped
                            ? TextDecoration.lineThrough
                            : null,
                        color: de.isSkipped ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      '${currencyFormat.format(e.amount)} \u00B7 ${e.type == 'recurring' ? 'Recorrente' : 'Unica'}',
                      style: TextStyle(
                        color: de.isSkipped ? Colors.grey : null,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (e.type == 'recurring' && !de.isPaid)
                          IconButton(
                            icon: Icon(
                              de.isSkipped
                                  ? Icons.replay
                                  : Icons.remove_circle_outline,
                              color: de.isSkipped ? Colors.orange : Colors.grey,
                              size: 22,
                            ),
                            tooltip: de.isSkipped
                                ? 'Repor despesa'
                                : 'Ignorar este mes',
                            onPressed: () async {
                              await ref
                                  .read(expenseActionsProvider)
                                  .toggleSkip(e.id, _currentMonth);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) setState(() {});
                            },
                          ),
                        if (!de.isSkipped)
                          Icon(
                            de.isPaid
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: color,
                          ),
                      ],
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExpenseFormPage(expense: e),
                        ),
                      );
                      if (result == true && mounted) setState(() {});
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Color _catColor(Category? cat) => cat != null
      ? Color(int.parse('FF${cat.colorHex.replaceAll('#', '')}', radix: 16))
      : Colors.grey;

  IconData _catIcon(Category? cat) {
    if (cat == null) return Icons.category;
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
    return iconMap[cat.iconName] ?? Icons.category;
  }
}

class _DayExpenses {
  final Expense expense;
  final bool isPaid;
  final bool isSkipped;
  _DayExpenses({
    required this.expense,
    required this.isPaid,
    required this.isSkipped,
  });
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: days
            .map(
              (d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
