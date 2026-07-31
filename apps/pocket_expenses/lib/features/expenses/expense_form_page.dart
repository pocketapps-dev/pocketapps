import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/expense.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/expense_provider.dart';
import '../../core/providers/profile_provider.dart';

class ExpenseFormPage extends ConsumerStatefulWidget {
  final Expense? expense;
  final int? initialDueDay;

  const ExpenseFormPage({super.key, this.expense, this.initialDueDay});

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _installmentsController = TextEditingController();

  String _type = 'recurring';
  bool _isVariable = false;
  String? _selectedCategoryId;
  int _frequency = 1;
  int _reminderDays = 3;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  bool get _isEditing => widget.expense != null;
  bool get _isRecurring => _type == 'recurring';
  bool get _isUnique => _type == 'unique';

  String get _typeDescription {
    if (_isUnique) return 'Única vez. Sem repetição. Ex: avaria.';
    return _isVariable
        ? 'Recorrente. Valor pode mudar a cada período. Ex: luz, água.'
        : 'Valor fixo todos os meses. Ex: renda, seguro.';
  }

  static const _frequencyLabels = {
    1: 'Mensal',
    2: 'Bimestral',
    3: 'Trimestral',
    6: 'Semestral',
    12: 'Anual',
  };

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.expense!;
      _nameController.text = e.name;
      _amountController.text = e.amount.toStringAsFixed(2);
      _type = e.type;
      _isVariable = e.isVariable;
      _selectedCategoryId = e.categoryId;
      _frequency = e.frequency ?? 1;
      _reminderDays = e.reminderDays;
      _startDate = e.startDate;
      _endDate = e.endDate;
      if (e.installments != null) {
        _installmentsController.text = e.installments.toString();
      }
    } else {
      _frequency = 1;
      _reminderDays = 3;
      if (widget.initialDueDay != null) {
        final now = DateTime.now();
        _startDate = DateTime(now.year, now.month, widget.initialDueDay!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleciona uma categoria')));
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRecurring ? 'Seleciona o dia de pagamento.' : 'Seleciona a data.',
          ),
        ),
      );
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSubmitting = true);

    final installments = int.tryParse(_installmentsController.text);
    final useInstallments =
        _isRecurring && installments != null && installments > 0;
    final useEndDate = _isRecurring && _endDate != null && !useInstallments;

    final expense = Expense(
      id: widget.expense?.id ?? '',
      userId: userId,
      categoryId: _selectedCategoryId!,
      name: _nameController.text.trim(),
      amount: double.parse(_amountController.text.replaceAll(',', '.')),
      type: _type,
      isVariable: _isVariable,
      dueDay: _isRecurring ? _startDate?.day : null,
      startDate: _startDate,
      endDate: useEndDate ? _endDate : null,
      installments: useInstallments ? installments : null,
      frequency: _isRecurring ? _frequency : null,
      reminderDays: _reminderDays,
      createdAt: widget.expense?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final notifier = ref.read(expenseActionsProvider);
    if (_isEditing) {
      await notifier.update(expense);
    } else {
      await notifier.create(expense);
    }

    ref.invalidate(expensesProvider(true));

    setState(() => _isSubmitting = false);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider('expenses'));
    final currencySymbols = {'EUR': '€', 'USD': '\$', 'GBP': '£', 'BRL': 'R\$'};
    final settings = ref.watch(settingsProvider);
    final currency = settings.value?['currency'] ?? 'EUR';
    final symbol = currencySymbols[currency] ?? currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Despesa' : 'Nova Despesa'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 1. Categoria
            _CategoryDropdown(
              categoriesAsync: categoriesAsync,
              selectedCategoryId: _selectedCategoryId,
              onChanged: (id) => setState(() => _selectedCategoryId = id),
            ),
            const SizedBox(height: 16),

            // 2. Tipo
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'recurring', child: Text('Recorrente')),
                DropdownMenuItem(value: 'unique', child: Text('Única')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _type = v;
                    if (_isUnique) {
                      _isVariable = false;
                      _installmentsController.clear();
                      _endDate = null;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _typeDescription,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),

            // 3. Valor fixo/variável (só recorrente)
            if (_isRecurring) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Valor fixo'),
                      selected: !_isVariable,
                      onSelected: (_) => setState(() => _isVariable = false),
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Valor variável'),
                      selected: _isVariable,
                      onSelected: (_) => setState(() => _isVariable = true),
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                    ),
                  ),
                ],
              ),
              if (_isVariable) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
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
                ),
              ],
            ],

            // 4. Nome
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome',
                hintText: 'Ex: Renda',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 50,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),

            // 5. Valor
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Valor ($symbol)',
                prefixText: '$symbol ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Obrigatório';
                final num = double.tryParse(v.replaceAll(',', '.'));
                if (num == null || num <= 0) return 'Valor inválido';
                return null;
              },
            ),

            // 6. Dia de Pagamento / Data
            if (_isRecurring) ...[
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dia de Pagamento'),
                subtitle: Text(
                  _startDate != null
                      ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                      : 'Selecionar data',
                  style: TextStyle(
                    color: _startDate != null
                        ? null
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: _isEditing ? DateTime(2020) : DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) setState(() => _startDate = date);
                },
              ),
              const SizedBox(height: 8),

              // 7. Termina em - info first
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Preenche apenas UM dos campos abaixo para definir quando a despesa termina:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Termina em'),
                subtitle: Text(
                  _endDate != null
                      ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                      : 'Selecionar data fim',
                  style: TextStyle(
                    color: _endDate != null
                        ? null
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_endDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() {
                          _endDate = null;
                          _installmentsController.clear();
                        }),
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? _startDate ?? DateTime.now(),
                    firstDate: _startDate ?? DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                      _installmentsController.clear();
                    });
                  }
                },
              ),
              const SizedBox(height: 8),

              // 8. Prestações
              TextFormField(
                controller: _installmentsController,
                decoration: const InputDecoration(
                  labelText: 'Nº de prestações',
                  hintText: 'Ex: 12',
                  suffixText: 'prestações',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (_) => setState(() {
                  if (_installmentsController.text.isNotEmpty) _endDate = null;
                }),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v);
                  if (n == null || n < 1) return 'Mínimo 1';
                  return null;
                },
              ),
            ],

            if (_isUnique) ...[
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data'),
                subtitle: Text(
                  _startDate != null
                      ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                      : 'Selecionar data',
                  style: TextStyle(
                    color: _startDate != null
                        ? null
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: _isEditing ? DateTime(2020) : DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) setState(() => _startDate = date);
                },
              ),
            ],

            // 9. Frequência
            if (_isRecurring) ...[
              const SizedBox(height: 16),
              Text(
                'Frequência',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _frequencyLabels.entries.map((entry) {
                  final isSelected = entry.key == _frequency;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _frequency = entry.key),
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                  );
                }).toList(),
              ),
            ],

            // 10. Lembrete
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lembrar $_reminderDays dia${_reminderDays == 1 ? '' : 's'} antes',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: _reminderDays,
              decoration: const InputDecoration(labelText: 'Lembrete'),
              items: List.generate(15, (i) => i + 1)
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text('$d dia${d == 1 ? '' : 's'}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _reminderDays = v);
              },
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Receber notificação $_reminderDays dia${_reminderDays == 1 ? '' : 's'} antes do dia de pagamento.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),

            // 11. Preview periódico
            if (_isRecurring && _startDate != null) ...[
              const SizedBox(height: 16),
              _PeriodicPreview(
                amount:
                    double.tryParse(
                      _amountController.text.replaceAll(',', '.'),
                    ) ??
                    0,
                startDate: _startDate!,
                installments: int.tryParse(_installmentsController.text),
                endDate: _endDate,
                frequency: _frequency,
                symbol: symbol,
              ),
            ],

            // 12. Botão guardar
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Guardar' : 'Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar despesa?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar permanentemente',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(expenseActionsProvider).delete(widget.expense!.id);
      ref.invalidate(expensesProvider(true));
      if (mounted) Navigator.of(context).pop();
    }
  }
}

// ── Category Dropdown with "+ Nova categoria" ──

class _CategoryDropdown extends ConsumerWidget {
  final AsyncValue<List<dynamic>> categoriesAsync;
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({
    required this.categoriesAsync,
    required this.selectedCategoryId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return categoriesAsync.when(
      data: (categories) {
        final filtered = categories.where((c) => c.name != 'Sem Categoria').toList();
        return DropdownButtonFormField<String>(
          initialValue: selectedCategoryId,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items: [
            ...filtered.map(
              (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
            ),
            DropdownMenuItem(
              value: '__add_new__',
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Nova categoria',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (v) {
            if (v == '__add_new__') {
              _showAddCategory(context, categories, onChanged);
            } else {
              onChanged(v);
            }
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Erro ao carregar categorias'),
    );
  }

  void _showAddCategory(
    BuildContext context,
    List categories,
    ValueChanged<String?> onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _InlineCategoryForm(
        onCreated: (newId) {
          onChanged(newId);
        },
      ),
    );
  }
}

// ── Inline Category Form ──

class _InlineCategoryForm extends ConsumerStatefulWidget {
  final ValueChanged<String> onCreated;
  const _InlineCategoryForm({required this.onCreated});

  @override
  ConsumerState<_InlineCategoryForm> createState() =>
      _InlineCategoryFormState();
}

class _InlineCategoryFormState extends ConsumerState<_InlineCategoryForm> {
  final _nameController = TextEditingController();
  String _selectedIcon = 'category';
  String _selectedColor = '#6366F1';
  bool _isLoading = false;

  static const _iconOptions = <String, IconData>{
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
    'pets': Icons.pets,
    'flight': Icons.flight,
    'fitness_center': Icons.fitness_center,
    'movie': Icons.movie,
    'health_and_safety': Icons.health_and_safety,
    'build': Icons.build,
    'child_care': Icons.child_care,
  };

  static const _colorOptions = [
    '#EF4444',
    '#F97316',
    '#F59E0B',
    '#10B981',
    '#3B82F6',
    '#8B5CF6',
    '#EC4899',
    '#6366F1',
    '#64748B',
    '#84CC16',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text(
            'Nova Categoria',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Ex: Viagens',
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Text(
            'Ícone',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _iconOptions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final entry = _iconOptions.entries.elementAt(i);
                final isSelected = entry.key == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = entry.key),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Icon(
                      entry.value,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cor',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _colorOptions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final hex = _colorOptions[i];
                final color = Color(
                  int.parse('FF${hex.replaceAll('#', '')}', radix: 16),
                );
                final isSelected = hex == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createCategory,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Adicionar'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _createCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nome é obrigatório.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final actions = ref.read(categoryActionsProvider);
      final category = await actions.create(
        name: name,
        iconName: _selectedIcon,
        colorHex: _selectedColor,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated(category.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Periodic Preview ──

class _PeriodicPreview extends StatelessWidget {
  final double amount;
  final DateTime startDate;
  final int? installments;
  final DateTime? endDate;
  final int frequency;
  final String symbol;

  static const _frequencyLabels = {
    1: 'Mensal',
    2: 'Bimestral',
    3: 'Trimestral',
    6: 'Semestral',
    12: 'Anual',
  };

  const _PeriodicPreview({
    required this.amount,
    required this.startDate,
    this.installments,
    this.endDate,
    required this.frequency,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final freqLabel = _frequencyLabels[frequency] ?? 'A cada $frequency meses';

    if (installments != null && installments! > 0) {
      final total = amount * installments!;
      return Card(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.calculate_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$installments × ${amount.toStringAsFixed(2)}$symbol ($freqLabel)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Total: ${total.toStringAsFixed(2)}$symbol',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (endDate != null) {
      final totalMonths =
          (endDate!.year - startDate.year) * 12 +
          (endDate!.month - startDate.month) +
          1;
      final intervals = (totalMonths / frequency).ceil();
      if (intervals <= 0) return const SizedBox();
      final total = amount * intervals;
      return Card(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.calculate_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$intervals × ${amount.toStringAsFixed(2)}$symbol ($freqLabel)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Total: ${total.toStringAsFixed(2)}$symbol',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final annualAmount = amount * (12 / frequency);
      return Card(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.repeat,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${amount.toStringAsFixed(2)}$symbol — $freqLabel',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '≈ ${annualAmount.toStringAsFixed(2)}$symbol/ano',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
