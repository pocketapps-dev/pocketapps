import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/currency_provider.dart';
import '../../core/models/category.dart';
import '../../core/models/expense.dart';
import '../../core/models/monthly_status.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/expense_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/subscription_provider.dart';
import '../settings/plans_page.dart';
import 'expense_form_page.dart';
import 'expense_wizard_page.dart';

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(
  SelectedMonthNotifier.new,
);

class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void setMonth(DateTime month) => state = month;
  void previousMonth() => state = DateTime(state.year, state.month - 1);
  void nextMonth() => state = DateTime(state.year, state.month + 1);
}

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final expensesAsync = ref.watch(expensesProvider(true));
    final statusesAsync = ref.watch(monthlyStatusesProvider(selectedMonth));
    final categoriesAsync = ref.watch(categoriesProvider('expenses'));

    return Scaffold(
      appBar: AppBar(title: const Text('Despesas')),
      body: Column(
        children: [
          _MonthSelector(
            selectedMonth: selectedMonth,
            onMonthChanged: (month) {
              ref.read(selectedMonthProvider.notifier).setMonth(month);
            },
          ),
          categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (categories) {
              final counts = <String, int>{};
              for (final e in expensesAsync.value ?? []) {
                final id = e.categoryId;
                counts[id] = (counts[id] ?? 0) + 1;
              }
              return _CategoryFilter(
                categories: categories,
                counts: counts,
                selectedId: _selectedCategoryId,
                onChanged: (id) => setState(() => _selectedCategoryId = id),
              );
            },
          ),
          Expanded(
            child: expensesAsync.when(
              data: (expenses) => statusesAsync.when(
                data: (statuses) => categoriesAsync.when(
                  data: (categories) {
                    final filtered = _selectedCategoryId != null
                        ? expenses
                              .where((e) => e.categoryId == _selectedCategoryId)
                              .toList()
                        : expenses;
                    return _ExpensesList(
                      expenses: filtered,
                      statuses: statuses,
                      selectedMonth: selectedMonth,
                      categories: categories,
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erro: $e')),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro: $e')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddOptions() async {
    final isPremium = (ref.read(subscriptionProvider).value?.isActive ?? false);
    // Aguarda o valor fresco das flags: ler .value diretamente pode devolver
    // null se o provider foi invalidado (ex.: apos usar o wizard gratis).
    final wizardUsed =
        (await ref.read(profileFlagsProvider.future)).wizardFreeUsed;
    if (!mounted) return;
    final wizardLocked = !isPremium && wizardUsed;
    final wizardFreeAvailable = !isPremium && !wizardUsed;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: wizardLocked
                      ? Colors.grey.shade300
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    wizardLocked ? Icons.lock : Icons.auto_awesome,
                    color: wizardLocked
                        ? Colors.grey.shade600
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Wizard passo a passo'),
                    if (wizardFreeAvailable) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Gratis',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                    if (wizardLocked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Premium',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  wizardLocked
                      ? 'Disponivel no plano Premium'
                      : wizardFreeAvailable
                          ? 'Experimenta gratis, resta 1 uso'
                          : 'Criar despesa guiada',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!wizardLocked) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ExpenseWizardPage(),
                      ),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'O Wizard passo a passo e uma funcionalidade Premium.',
                      ),
                    ),
                  );
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlansPage()),
                  );
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.edit_document,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                title: const Text('Formulario completo'),
                subtitle: const Text('Todos os campos de uma vez'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExpenseFormPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const _MonthSelector({
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MMMM yyyy', 'pt_PT');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prev = DateTime(
                selectedMonth.year,
                selectedMonth.month - 1,
              );
              onMonthChanged(prev);
            },
          ),
          Text(
            monthFormat.format(selectedMonth),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final next = DateTime(
                selectedMonth.year,
                selectedMonth.month + 1,
              );
              onMonthChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final List<Category> categories;
  final Map<String, int> counts;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _CategoryFilter({
    required this.categories,
    required this.counts,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Todas'),
              selected: selectedId == null,
              onSelected: (_) => onChanged(null),
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          ...categories.map((cat) {
            final color = Color(
              int.parse('FF${cat.colorHex.replaceAll('#', '')}', radix: 16),
            );
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(
                  _getIconData(cat.iconName),
                  size: 16,
                  color: color,
                ),
                label: Text(
                  '${cat.name} (${counts[cat.id] ?? 0})',
                ),
                selected: selectedId == cat.id,
                onSelected: (_) =>
                    onChanged(selectedId == cat.id ? null : cat.id),
                selectedColor: color.withValues(alpha: 0.15),
              ),
            );
          }),
        ],
      ),
    );
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

class _ExpensesList extends ConsumerWidget {
  final List<Expense> expenses;
  final Map<String, MonthlyStatus> statuses;
  final DateTime selectedMonth;
  final List<Category> categories;

  const _ExpensesList({
    required this.expenses,
    required this.statuses,
    required this.selectedMonth,
    required this.categories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyCode = ref.watch(currencyProvider);
    final currencyFormat = currencyFormatFor(currencyCode);

    if (expenses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Sem despesas', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final activeExpenses = expenses
        .where((e) => statuses[e.id]?.isSkipped != true)
        .toList();
    final total = activeExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final paid = activeExpenses
        .where((e) => statuses[e.id]?.isPaid == true)
        .fold<double>(0, (sum, e) => sum + e.amount);

    return Column(
      children: [
        _SummaryCard(
          total: total,
          paid: paid,
          unpaid: total - paid,
          currencyFormat: currencyFormat,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              final status = statuses[expense.id];
              return _ExpenseTile(
                expense: expense,
                status: status,
                currencyFormat: currencyFormat,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExpenseFormPage(expense: expense),
                    ),
                  );
                },
                onTogglePaid: () async {
                  await ref
                      .read(expenseActionsProvider)
                      .togglePaid(expense.id, selectedMonth);
                  ref.invalidate(expensesProvider(true));
                  ref.invalidate(monthlyStatusesProvider(selectedMonth));
                },
                onToggleSkip: () async {
                  await ref
                      .read(expenseActionsProvider)
                      .toggleSkip(expense.id, selectedMonth);
                  ref.invalidate(expensesProvider(true));
                  ref.invalidate(monthlyStatusesProvider(selectedMonth));
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double total;
  final double paid;
  final double unpaid;
  final NumberFormat currencyFormat;

  const _SummaryCard({
    required this.total,
    required this.paid,
    required this.unpaid,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryItem(
              label: 'Total',
              value: currencyFormat.format(total),
              color: Theme.of(context).colorScheme.primary,
            ),
            _SummaryItem(
              label: 'Pago',
              value: currencyFormat.format(paid),
              color: Colors.green,
            ),
            _SummaryItem(
              label: 'Pendente',
              value: currencyFormat.format(unpaid),
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final MonthlyStatus? status;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;
  final VoidCallback onTogglePaid;
  final VoidCallback onToggleSkip;

  const _ExpenseTile({
    required this.expense,
    required this.status,
    required this.currencyFormat,
    required this.onTap,
    required this.onTogglePaid,
    required this.onToggleSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = status?.isPaid == true;
    final isSkipped = status?.isSkipped == true;
    final color = expense.categoryColor != null
        ? Color(
            int.parse(
              'FF${expense.categoryColor!.replaceAll('#', '')}',
              radix: 16,
            ),
          )
        : Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isPaid,
              onChanged: (_) => onTogglePaid(),
              activeColor: Colors.green,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            CircleAvatar(
              backgroundColor: color,
              child: Icon(
                _getIconData(expense.categoryIcon ?? 'category'),
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
        title: Text(
          expense.name,
          style: TextStyle(
            decoration: isSkipped ? TextDecoration.lineThrough : null,
            color: isSkipped ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          expense.categoryName ?? 'Sem categoria',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currencyFormat.format(expense.amount),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isPaid
                    ? Colors.green
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton(
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExpenseFormPage(expense: expense),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: onToggleSkip,
                  child: ListTile(
                    leading: Icon(
                      isSkipped ? Icons.undo : Icons.skip_next,
                      color: isSkipped ? Colors.orange : null,
                    ),
                    title: Text(isSkipped ? 'Repor' : 'Pular este mes'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Editar'),
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
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
