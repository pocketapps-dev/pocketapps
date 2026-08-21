import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/category.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/subscription_provider.dart';
import '../settings/plans_page.dart';

const kFreeCategoryLimit = 10;

const _iconMap = <String, IconData>{
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
  'pets': Icons.pets,
  'flight': Icons.flight,
  'fitness_center': Icons.fitness_center,
  'music_note': Icons.music_note,
  'movie': Icons.movie,
  'health_and_safety': Icons.health_and_safety,
  'build': Icons.build,
  'child_care': Icons.child_care,
  'cafe': Icons.local_cafe,
  'liquor': Icons.local_bar,
  'grocery': Icons.local_grocery_store,
  'store': Icons.store,
  'spa': Icons.spa,
  'park': Icons.park,
  'beach_access': Icons.beach_access,
  'church': Icons.church,
  'child_friendly': Icons.child_friendly,
  'elderly': Icons.elderly,
  'computer': Icons.computer,
  'phone_android': Icons.phone_android,
  'tv': Icons.tv,
  'camera': Icons.camera_alt,
  'brush': Icons.brush,
  'palette': Icons.palette,
  'engineering': Icons.engineering,
  'agriculture': Icons.agriculture,
  'bug_report': Icons.bug_report,
  'eco': Icons.eco,
  'recycling': Icons.recycling,
  'local_hospital': Icons.local_hospital,
  'psychology': Icons.psychology,
  'inventory': Icons.inventory,
  'inventory_2': Icons.inventory_2,
  'request_quote': Icons.request_quote,
  'receipt_long': Icons.receipt_long,
  'savings': Icons.savings,
  'trending_up': Icons.trending_up,
  'wallet': Icons.account_balance_wallet,
  'credit_card': Icons.credit_card,
  'paid': Icons.paid,
  'redeem': Icons.redeem,
  'card_giftcard': Icons.card_giftcard,
  'volunteer_activism': Icons.volunteer_activism,
  'military_tech': Icons.military_tech,
  'emoji_events': Icons.emoji_events,
  'celebration': Icons.celebration,
  'cake': Icons.cake,
  'emoji_emotions': Icons.emoji_emotions,
  'diamond': Icons.diamond,
  'auto_awesome': Icons.auto_awesome,
};

const _colorPresets = [
  '#EF4444',
  '#F97316',
  '#F59E0B',
  '#EAB308',
  '#84CC16',
  '#22C55E',
  '#10B981',
  '#14B8A6',
  '#06B6D4',
  '#0EA5E9',
  '#3B82F6',
  '#6366F1',
  '#8B5CF6',
  '#A855F7',
  '#D946EF',
  '#EC4899',
  '#F43F5E',
  '#DC2626',
  '#78716C',
  '#64748B',
];

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(categoryActionsProvider).ensureDefaultCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider('expenses'));
    final subscription = ref.watch(subscriptionProvider).asData?.value;
    final isPremium = subscription?.isActive == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('Sem categorias'));
          }
          return Column(
            children: [
              if (!isPremium) _FreeLimitBanner(count: categories.length),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  buildDefaultDragHandles: false,
                  itemCount: categories.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final ids = categories.map((c) => c.id).toList();
                    final id = ids.removeAt(oldIndex);
                    ids.insert(newIndex, id);
                    ref.read(categoryActionsProvider).reorder(ids);
                  },
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isUncategorized = cat.name == 'Sem Categoria';
                    final color = Color(
                      int.parse(
                        'FF${cat.colorHex.replaceAll('#', '')}',
                        radix: 16,
                      ),
                    );
                    final icon = _iconMap[cat.iconName] ?? Icons.category;

                    return ListTile(
                      key: ValueKey(cat.id),
                      leading: CircleAvatar(
                        backgroundColor: color,
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      title: Text(cat.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isUncategorized)
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 20,
                                color: Colors.red,
                              ),
                              onPressed: () => _confirmDelete(
                                context,
                                ref,
                                cat.id,
                                cat.name,
                              ),
                            ),
                          if (!isUncategorized)
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle),
                            ),
                        ],
                      ),
                      onTap: isUncategorized
                          ? null
                          : () =>
                                _showCategoryDialog(context, ref, category: cat),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAddPressed(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _onAddPressed(BuildContext context) {
    final subscription = ref.read(subscriptionProvider).asData?.value;
    final isPremium = subscription?.isActive == true;
    final count =
        ref.read(categoriesProvider('expenses')).asData?.value.length ?? 0;

    if (!isPremium && count >= kFreeCategoryLimit) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Limite do plano Free'),
          content: Text(
            'O plano Free permite até $kFreeCategoryLimit categorias.\n\n'
            'Subscreve o plano Premium para criar categorias ilimitadas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlansPage()),
                );
              },
              child: const Text('Ver Premium'),
            ),
          ],
        ),
      );
      return;
    }

    _showCategoryDialog(context, ref);
  }

  void _showCategoryDialog(
    BuildContext context,
    WidgetRef ref, {
    Category? category,
  }) {
    final existingCategories =
        ref.read(categoriesProvider('expenses')).asData?.value ?? [];
    final isEditing = category != null;
    final nameController = TextEditingController(
      text: isEditing ? category.name : '',
    );
    String selectedIcon = isEditing ? category.iconName : 'category';
    String selectedColor = isEditing ? category.colorHex : '#6366F1';

    final usedIcons = existingCategories
        .where((c) => c.id != category?.id)
        .map((c) => c.iconName)
        .toSet();
    final usedColors = existingCategories
        .where((c) => c.id != category?.id)
        .map((c) => c.colorHex)
        .toSet();
    final availableIcons = _iconMap.entries
        .where((e) => !usedIcons.contains(e.key))
        .toList();
    final availableColors = _colorPresets
        .where((c) => !usedColors.contains(c))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditing ? 'Editar Categoria' : 'Nova Categoria',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 20),
                Text(
                  'Ícone',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: availableIcons.isEmpty
                      ? const Center(
                          child: Text('Todos os ícones já estão em uso'),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 8,
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4,
                              ),
                          itemCount: availableIcons.length,
                          itemBuilder: (context, index) {
                            final entry = availableIcons[index];
                            final isSelected = entry.key == selectedIcon;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => selectedIcon = entry.key),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.15)
                                      : Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[850]
                                          : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected
                                      ? Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: Icon(entry.value, size: 20),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Cor',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showColorPicker(
                        ctx,
                        setState,
                        selectedColor,
                        (color) {
                          selectedColor = color;
                        },
                      ),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(
                              'FF${selectedColor.replaceAll('#', '')}',
                              radix: 16,
                            ),
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: availableColors.isEmpty
                      ? const Center(
                          child: Text('Todas as cores já estão em uso'),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: availableColors.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final hex = availableColors[index];
                            final color = Color(
                              int.parse(
                                'FF${hex.replaceAll('#', '')}',
                                radix: 16,
                              ),
                            );
                            final isSelected = hex == selectedColor;
                            return GestureDetector(
                              onTap: () => setState(() => selectedColor = hex),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: Colors.black,
                                          width: 3,
                                        )
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final actions = ref.read(categoryActionsProvider);
                    if (isEditing) {
                      await actions.update(
                        id: category.id,
                        name: name,
                        iconName: selectedIcon,
                        colorHex: selectedColor,
                      );
                    } else {
                      await actions.create(
                        name: name,
                        iconName: selectedIcon,
                        colorHex: selectedColor,
                      );
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(isEditing ? 'Guardar' : 'Criar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPicker(
    BuildContext context,
    StateSetter setState,
    String currentColor,
    Function(String) onColorChanged,
  ) {
    Color pickerColor = Color(
      int.parse('FF${currentColor.replaceAll('#', '')}', radix: 16),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escolher cor'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final hex =
                  '#${pickerColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
              onColorChanged(hex);
              Navigator.of(ctx).pop();
            },
            child: const Text('Escolher'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoria?'),
        content: Text(
          'Eliminar "$name"? As despesas associadas ficarão sem categoria.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(categoryActionsProvider).delete(id);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _FreeLimitBanner extends StatelessWidget {
  const _FreeLimitBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final remaining = kFreeCategoryLimit - count;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlansPage()),
      ),
      child: Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                remaining > 0
                    ? '$count/$kFreeCategoryLimit categorias no plano Free · restam $remaining'
                    : 'Limite do plano Free atingido',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Text(
              'Ver Premium',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
