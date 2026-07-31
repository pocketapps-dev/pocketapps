import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/expense.dart';
import '../../core/models/monthly_status.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/expense_provider.dart';
import '../expenses/expenses_page.dart';

class SummaryPage extends ConsumerWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final expensesAsync = ref.watch(expensesProvider(true));
    final statusesAsync = ref.watch(monthlyStatusesProvider(selectedMonth));
    final categoriesAsync = ref.watch(categoriesProvider('expenses'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(selectedMonthProvider.notifier).previousMonth(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Text(
                DateFormat('MMM yyyy', 'pt_PT').format(selectedMonth),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(selectedMonthProvider.notifier).nextMonth(),
          ),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (expenses) {
          return statusesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (statuses) {
              return categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro: $e')),
                data: (categories) {
                  return _buildSummary(context, ref, expenses, statuses, categories, selectedMonth);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    WidgetRef ref,
    List<Expense> expenses,
    Map<String, MonthlyStatus> statuses,
    List categories,
    DateTime month,
  ) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

    double total = 0;
    double paid = 0;
    double unpaid = 0;
    final Map<String, double> categoryTotals = {};
    final Map<String, String> categoryNames = {};
    final Map<String, String> categoryColors = {};

    for (final cat in categories) {
      categoryNames[cat.id] = cat.name;
      categoryColors[cat.id] = cat.colorHex;
    }

    for (final expense in expenses) {
      final status = statuses[expense.id];
      final isPaid = status?.isPaid ?? false;
      final isSkipped = status?.isSkipped ?? false;
      if (isSkipped) continue;

      final amount = expense.amount;
      total += amount;

      if (isPaid) {
        paid += amount;
      } else {
        unpaid += amount;
      }

      final catName = categoryNames[expense.categoryId] ?? 'Sem categoria';
      categoryTotals[catName] = (categoryTotals[catName] ?? 0) + amount;
    }

    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Sem dados para este mês', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SummaryCard(
                title: 'Total',
                value: currencyFormat.format(total),
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                title: 'Pago',
                value: currencyFormat.format(paid),
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                title: 'Por pagar',
                value: currencyFormat.format(unpaid),
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (categoryTotals.isNotEmpty) ...[
            Text('Despesas por categoria', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: _buildPieSections(categoryTotals, categoryColors, total),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...categoryTotals.entries.map((entry) {
              final percentage = ((entry.value / total) * 100).toStringAsFixed(1);
              final colorHex = categoryColors.entries
                  .where((e) => e.value == entry.key)
                  .map((e) => e.value)
                  .firstOrNull;
              final color = colorHex != null
                  ? Color(int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16))
                  : Colors.grey;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(entry.key)),
                    Text(currencyFormat.format(entry.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('$percentage%', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
    Map<String, double> categoryTotals,
    Map<String, String> categoryColors,
    double total,
  ) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];

    int i = 0;
    return categoryTotals.entries.map((entry) {
      final percentage = (entry.value / total) * 100;
      final color = colors[i % colors.length];
      i++;
      return PieChartSectionData(
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        color: color,
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
