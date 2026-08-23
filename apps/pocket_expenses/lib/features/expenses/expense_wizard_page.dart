import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/category.dart';
import '../../core/models/expense.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/expense_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/subscription_provider.dart';
import '../home/home_page.dart';
import '../settings/plans_page.dart';

class ExpenseWizardPage extends ConsumerStatefulWidget {
  const ExpenseWizardPage({super.key});

  @override
  ConsumerState<ExpenseWizardPage> createState() => _ExpenseWizardPageState();
}

class _ExpenseWizardPageState extends ConsumerState<ExpenseWizardPage> {
  final _pageCtrl = PageController();
  int _step = 0;

  String _type = 'recurring';
  String? _categoryId;
  bool _isVariable = false;
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _installmentsCtrl = TextEditingController();
  int _frequency = 1;
  final int _reminderDays = 3;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _uniqueDate;

  bool get _isRecurring => _type == 'recurring';

  int get _totalSteps => _isRecurring ? 7 : 6;

  static const _frequencyLabels = {
    1: 'Mensal',
    2: 'Bimestral',
    3: 'Trimestral',
    6: 'Semestral',
    12: 'Anual',
  };

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _installmentsCtrl.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (!_validateCurrentStep()) return;
    if (_step < _totalSteps - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _step++);
    }
  }

  void _prev() {
    FocusScope.of(context).unfocus();
    if (_step > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _step--);
    }
  }

  bool _validateCurrentStep() {
    switch (_step) {
      case 2:
        if (_nameCtrl.text.trim().isEmpty) {
          _showError('Insere um nome.');
          return false;
        }
        return true;
      case 3:
        final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
        if (amount == null || amount <= 0) {
          _showError('Insere um valor valido.');
          return false;
        }
        return true;
      case 4:
        if (_isRecurring) {
          if (_startDate == null) {
            _showError('Seleciona o dia de pagamento.');
            return false;
          }
        } else {
          if (_uniqueDate == null) {
            _showError('Seleciona uma data.');
            return false;
          }
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final isPremium =
        (ref.read(subscriptionProvider).value?.isActive ?? false);
    if (!isPremium) {
      // Guarda duro: mesmo que o ecra anterior tenha deixado passar, confirma
      // o valor fresco das flags antes de criar a despesa.
      final used =
          (await ref.read(profileFlagsProvider.future)).wizardFreeUsed;
      if (used) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('O Wizard passo a passo e uma funcionalidade Premium.'),
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PlansPage()),
        );
        return;
      }
    }

    final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));
    final installments = int.tryParse(_installmentsCtrl.text);
    final useInstallments =
        _isRecurring && installments != null && installments > 0;
    final useEndDate = _isRecurring && _endDate != null && !useInstallments;

    final expense = Expense(
      id: '',
      userId: userId,
      categoryId: _categoryId ?? '',
      name: _nameCtrl.text.trim(),
      amount: amount,
      type: _type,
      isVariable: _isVariable,
      dueDay: _isRecurring && _startDate != null ? _startDate!.day : null,
      startDate: _isRecurring ? _startDate : _uniqueDate,
      endDate: useEndDate ? _endDate : null,
      installments: useInstallments ? installments : null,
      frequency: _isRecurring ? _frequency : null,
      reminderDays: _reminderDays,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(expenseActionsProvider).create(expense);
    } catch (e) {
      if (mounted) _showError('Erro ao guardar: $e');
      return;
    }

    ref.invalidate(expensesProvider(true));

    final sub = await ref.read(subscriptionProvider.future);
    if (!(sub?.isActive ?? false)) {
      try {
        await ref.read(profileActionsProvider).markWizardFreeUsed();
      } catch (_) {}
    }

    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Despesa criada!'),
        content: Text(
          '${expense.name} \u2014 ${expense.amount.toStringAsFixed(2)}\u20AC',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'done'),
            child: const Text('Ir para a app'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'another'),
            child: const Text('Criar outra'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'another') {
      // Bloqueio antecipado: antes de deixar o utilizador preencher outra
      // despesa, exige Premium se o uso gratuito do wizard ja foi consumido.
      if (!(sub?.isActive ?? false)) {
        final used =
            (await ref.read(profileFlagsProvider.future)).wizardFreeUsed;
        if (used) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('O Wizard passo a passo e uma funcionalidade Premium.'),
            ),
          );
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlansPage()),
          );
          return;
        }
      }
      setState(() {
        _step = 0;
        _nameCtrl.clear();
        _amountCtrl.clear();
        _installmentsCtrl.clear();
        _type = 'recurring';
        _categoryId = null;
        _isVariable = false;
        _frequency = 1;
        _startDate = null;
        _endDate = null;
        _uniqueDate = null;
      });
      _pageCtrl.jumpToPage(0);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    }
  }

  List<Widget> _buildSteps() {
    final steps = <Widget>[
      _StepType(
        type: _type,
        onChanged: (t) {
          setState(() => _type = t);
          if (t == 'unique') {
            _isVariable = false;
            _installmentsCtrl.clear();
            _endDate = null;
          }
        },
      ),
      _StepCategory(
        selected: _categoryId,
        onChanged: (c) => setState(() => _categoryId = c),
      ),
      _StepName(controller: _nameCtrl),
      _StepAmount(
        controller: _amountCtrl,
        isVariable: _isVariable,
        onToggleVariable: (v) => setState(() => _isVariable = v),
      ),
    ];

    if (_isRecurring) {
      steps.add(
        _StepPagamento(
          date: _startDate,
          onDatePicked: (d) => setState(() => _startDate = d),
          frequency: _frequency,
          frequencyLabels: _frequencyLabels,
          onFrequencyChanged: (f) => setState(() => _frequency = f),
        ),
      );
      steps.add(
        _StepEndOption(
          endDate: _endDate,
          installmentsCtrl: _installmentsCtrl,
          onEndDateChanged: (d) => setState(() {
            _endDate = d;
            _installmentsCtrl.clear();
          }),
          onInstallmentsChanged: (v) => setState(() {
            _installmentsCtrl.text = v;
            _endDate = null;
          }),
        ),
      );
    } else {
      steps.add(
        _StepDate(
          date: _uniqueDate,
          onPicked: (d) => setState(() => _uniqueDate = d),
        ),
      );
    }

    steps.add(
      _StepSummary(
        type: _type,
        categoryId: _categoryId,
        name: _nameCtrl.text.trim(),
        amount: double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0,
        isVariable: _isVariable,
        frequency: _frequency,
        frequencyLabels: _frequencyLabels,
        startDate: _isRecurring ? _startDate : _uniqueDate,
        endDate: _endDate,
        installments: int.tryParse(_installmentsCtrl.text),
      ),
    );

    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    final isPremium =
        (ref.watch(subscriptionProvider).value?.isActive ?? false);
    final wizardUsed =
        (ref.watch(profileFlagsProvider).value?.wizardFreeUsed ?? false);
    final showFreeBanner = !isPremium && !wizardUsed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Despesa'),
        leading: _step > 0
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _prev)
            : null,
      ),
      body: Column(
        children: [
          if (showFreeBanner)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Uso gratuito: depois de guardares, o Wizard passa a ser exclusivo do Premium.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: List.generate(_totalSteps, (i) {
                final active = i <= _step;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: steps,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _step == _totalSteps - 1 ? _save : _next,
                child: Text(_step == _totalSteps - 1 ? 'Guardar' : 'Seguinte'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared header ──

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _StepHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Step 1: Type ──

class _StepType extends StatelessWidget {
  final String type;
  final ValueChanged<String> onChanged;
  const _StepType({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepHeader(
            icon: Icons.category_outlined,
            title: 'Que tipo de despesa?',
            subtitle: 'Escolhe o tipo que melhor se adequa.',
          ),
          const SizedBox(height: 24),
          _TypeOption(
            icon: Icons.repeat,
            title: 'Recorrente',
            subtitle: 'Repete todos os meses. Ex: renda, luz, Internet.',
            selected: type == 'recurring',
            onTap: () => onChanged('recurring'),
          ),
          const SizedBox(height: 12),
          _TypeOption(
            icon: Icons.one_x_mobiledata,
            title: 'Unica',
            subtitle: 'Acontece uma vez. Ex: avaria, compra pontual.',
            selected: type == 'unique',
            onTap: () => onChanged('unique'),
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _TypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primary : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? primary : Colors.grey, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: primary),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Category ──

class _StepCategory extends ConsumerWidget {
  final String? selected;
  final ValueChanged<String> onChanged;
  const _StepCategory({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider('expenses'));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            icon: Icons.category_outlined,
            title: 'Categoria',
            subtitle: 'Em que categoria se enquadra?',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (categories) {
                final filtered = categories.where((c) => c.name != 'Sem Categoria').toList();
                return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final cat = filtered[i];
                  final isSelected = cat.id == selected;
                  final color = Color(
                    int.parse(
                      'FF${cat.colorHex.replaceAll('#', '')}',
                      radix: 16,
                    ),
                  );
                  return GestureDetector(
                    onTap: () => onChanged(cat.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? color : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getIconData(cat.iconName),
                            color: color,
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cat.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            ),
          ),
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

// ── Step 3: Name ──

class _StepName extends StatelessWidget {
  final TextEditingController controller;
  const _StepName({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            _StepHeader(
              icon: Icons.edit_outlined,
              title: 'Como se chama?',
              subtitle: 'Um nome curto para identificar a despesa.',
            ),
            const SizedBox(height: 32),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Nome',
                hintText: 'Ex: Renda, Luz, Internet...',
              ),
              onSubmitted: (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 4: Amount ──

class _StepAmount extends StatelessWidget {
  final TextEditingController controller;
  final bool isVariable;
  final ValueChanged<bool> onToggleVariable;
  const _StepAmount({
    required this.controller,
    required this.isVariable,
    required this.onToggleVariable,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            _StepHeader(
              icon: Icons.euro_outlined,
              title: 'Qual o valor?',
              subtitle: 'Valor mensal ou total da despesa.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixText: '\u20AC ',
                labelText: 'Valor',
              ),
              onSubmitted: (_) {},
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Valor fixo'),
                    selected: !isVariable,
                    onSelected: (_) => onToggleVariable(false),
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Valor variavel'),
                    selected: isVariable,
                    onSelected: (_) => onToggleVariable(true),
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                  ),
                ),
              ],
            ),
            if (isVariable) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Atualiza o valor quando receberes a factura.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Step 5: Dia de Pagamento (recurring) ──

class _StepPagamento extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime> onDatePicked;
  final int frequency;
  final Map<int, String> frequencyLabels;
  final ValueChanged<int> onFrequencyChanged;
  const _StepPagamento({
    required this.date,
    required this.onDatePicked,
    required this.frequency,
    required this.frequencyLabels,
    required this.onFrequencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            _StepHeader(
              icon: Icons.calendar_today_outlined,
              title: 'Dia de Pagamento',
              subtitle: 'Quando comeca e com que frequencia.',
            ),
            const SizedBox(height: 24),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              title: Text(
                date != null
                    ? '${date!.day}/${date!.month}/${date!.year}'
                    : 'Selecionar dia de pagamento',
                style: TextStyle(
                  color: date != null
                      ? null
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (picked != null) onDatePicked(picked);
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Frequencia',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: frequencyLabels.entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: entry.key == frequency,
                  onSelected: (_) => onFrequencyChanged(entry.key),
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 5b: Date (unique) ──

class _StepDate extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime> onPicked;
  const _StepDate({required this.date, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepHeader(
            icon: Icons.event_outlined,
            title: 'Qual a data?',
            subtitle: 'Data em que a despesa ocorre.',
          ),
          const SizedBox(height: 24),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            title: Text(
              date != null
                  ? '${date!.day}/${date!.month}/${date!.year}'
                  : 'Selecionar data',
              style: TextStyle(
                color: date != null
                    ? null
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (picked != null) onPicked(picked);
            },
          ),
        ],
      ),
    );
  }
}

// ── Step 6: End date / installments (recurring, optional) ──

class _StepEndOption extends StatelessWidget {
  final DateTime? endDate;
  final TextEditingController installmentsCtrl;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<String> onInstallmentsChanged;
  const _StepEndOption({
    required this.endDate,
    required this.installmentsCtrl,
    required this.onEndDateChanged,
    required this.onInstallmentsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            _StepHeader(
              icon: Icons.event_repeat_outlined,
              title: 'Termina em?',
              subtitle: 'Opcional. Pode deixar vazio para sempre.',
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              title: Text(
                endDate != null
                    ? '${endDate!.day}/${endDate!.month}/${endDate!.year}'
                    : 'Selecionar data fim',
                style: TextStyle(
                  color: endDate != null
                      ? null
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (endDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => onEndDateChanged(null),
                    ),
                  const Icon(Icons.calendar_today),
                ],
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: endDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (picked != null) onEndDateChanged(picked);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: installmentsCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                labelText: 'No. de prestacoes',
                hintText: 'Ex: 12',
                suffixText: 'prestacoes',
              ),
              onChanged: onInstallmentsChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Preenche data fim OU prestacoes. Ambos vazios = para sempre.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step Summary ──

class _StepSummary extends ConsumerWidget {
  final String type;
  final String? categoryId;
  final String name;
  final double amount;
  final bool isVariable;
  final int frequency;
  final Map<int, String> frequencyLabels;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? installments;

  const _StepSummary({
    required this.type,
    this.categoryId,
    required this.name,
    required this.amount,
    required this.isVariable,
    required this.frequency,
    required this.frequencyLabels,
    this.startDate,
    this.endDate,
    this.installments,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider('expenses'));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _StepHeader(
              icon: Icons.summarize_outlined,
              title: 'Resumo',
              subtitle: 'Confirma os dados antes de guardar.',
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erro: $e'),
              data: (categories) {
                Category? cat;
                if (categoryId != null) {
                  cat = categories.where((c) => c.id == categoryId).firstOrNull;
                }
                final color = cat != null
                    ? Color(
                        int.parse(
                          'FF${cat.colorHex.replaceAll('#', '')}',
                          radix: 16,
                        ),
                      )
                    : Colors.grey;
                final iconMap = <String, IconData>{
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

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      if (cat != null)
                        CircleAvatar(
                          backgroundColor: color,
                          child: Icon(
                            iconMap[cat.iconName] ?? Icons.category,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat?.name ?? 'Sem categoria',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${amount.toStringAsFixed(2)}\u20AC',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      _SummaryRow(
                        label: 'Tipo',
                        value: type == 'recurring' ? 'Recorrente' : 'Unica',
                      ),
                      if (isVariable)
                        _SummaryRow(label: 'Valor', value: 'Variavel'),
                      if (startDate != null)
                        _SummaryRow(
                          label: 'Dia de Pagamento',
                          value:
                              '${startDate!.day}/${startDate!.month}/${startDate!.year}',
                        ),
                      if (type == 'recurring')
                        _SummaryRow(
                          label: 'Frequencia',
                          value: frequencyLabels[frequency] ?? '',
                        ),
                      if (endDate != null)
                        _SummaryRow(
                          label: 'Termina em',
                          value:
                              '${endDate!.day}/${endDate!.month}/${endDate!.year}',
                        ),
                      if (installments != null)
                        _SummaryRow(
                          label: 'No. de prestacoes',
                          value: '$installments',
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
