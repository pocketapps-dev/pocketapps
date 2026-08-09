import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme_provider.dart';
import '../../core/models/theme_info.dart';
import '../../core/providers/subscription_provider.dart';
import '../../core/providers/theme_store_provider.dart';

class ThemesPage extends ConsumerWidget {
  const ThemesPage({super.key});

  static const _storeUrl = 'https://pocketapps.pt/themes.html';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(themeStoreProvider);
    final currentTheme = ref.watch(themeNameProvider);
    final subscription = ref.watch(subscriptionProvider).value;
    final isPremium = subscription?.isActive == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Temas')),
      body: themesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          onRetry: () => ref.invalidate(themeStoreProvider),
        ),
        data: (themes) {
          if (themes.isEmpty) {
            return const Center(child: Text('Sem temas disponíveis'));
          }

          final free = themes.where((t) => t.isFree).toList();
          final premium = themes.where((t) => t.isPremium).toList();
          final paid = themes.where((t) => t.isPaid).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!isPremium) ...[
                _PremiumBanner(onTap: () => context.push('/settings/plans')),
                const SizedBox(height: 16),
              ],
              if (free.isNotEmpty) ...[
                const _SectionLabel('GRÁTIS'),
                const SizedBox(height: 8),
                _ThemeCard(
                  themes: free,
                  currentTheme: currentTheme,
                  onApply: (t) => _apply(ref, t),
                  onLocked: (t) {},
                ),
                const SizedBox(height: 16),
              ],
              if (premium.isNotEmpty) ...[
                const _SectionLabel('PREMIUM'),
                const SizedBox(height: 8),
                _ThemeCard(
                  themes: premium,
                  currentTheme: currentTheme,
                  onApply: (t) => _apply(ref, t),
                  onLocked: (t) => context.push('/settings/plans'),
                ),
                const SizedBox(height: 16),
              ],
              if (paid.isNotEmpty) ...[
                const _SectionLabel('TEMAS PAGOS'),
                const SizedBox(height: 8),
                _ThemeCard(
                  themes: paid,
                  currentTheme: currentTheme,
                  onApply: (t) => _apply(ref, t),
                  onLocked: (t) => _openStore(context),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showThemeCodeDialog(context, ref),
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: const Text('Ativar código de tema'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _apply(WidgetRef ref, ThemeInfo theme) {
    ref.read(themeModeProvider.notifier).setMode(
      theme.brightness == 'dark' ? ThemeMode.dark : ThemeMode.light,
    );
    ref.read(themeNameProvider.notifier).setTheme(theme.name);
  }

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.parse(_storeUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir a loja de temas'),
          ),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A compra é feita no site. Assim que comprares, o tema aparece aqui automaticamente.',
          ),
        ),
      );
    }
  }

  void _showThemeCodeDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    var isLoading = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Código de Tema'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Código',
              prefixIcon: Icon(Icons.vpn_key),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      final message = await ref
                          .read(themeStoreActionsProvider)
                          .redeemThemeCode(controller.text);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: message.startsWith('Tema')
                                ? Colors.green
                                : Colors.red,
                          ),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ativar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade500,
      ),
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_outlined, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Desbloqueia os temas Premium',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Midnight, Forest e Sunset incluídos no plano Premium.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onTap,
              child: const Text('Ver planos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.themes,
    required this.currentTheme,
    required this.onApply,
    required this.onLocked,
  });

  final List<ThemeInfo> themes;
  final String currentTheme;
  final void Function(ThemeInfo) onApply;
  final void Function(ThemeInfo) onLocked;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < themes.length; i++) ...[
            _ThemeTile(
              theme: themes[i],
              selected: themes[i].name == currentTheme,
              onApply: () => onApply(themes[i]),
              onLocked: () => onLocked(themes[i]),
            ),
            if (i < themes.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.onApply,
    required this.onLocked,
  });

  final ThemeInfo theme;
  final bool selected;
  final VoidCallback onApply;
  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    final locked = !theme.available;

    final Widget trailing;
    if (selected) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            'Ativo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );
    } else if (locked) {
      trailing = TextButton(
        onPressed: onLocked,
        child: Text(theme.isPremium ? 'Premium' : theme.priceLabel),
      );
    } else {
      trailing = TextButton(onPressed: onApply, child: const Text('Aplicar'));
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.seedColor,
        child: Icon(
          selected
              ? Icons.check
              : locked
                  ? Icons.lock_outline
                  : Icons.format_color_fill,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(theme.name),
      subtitle: Text(theme.description),
      trailing: trailing,
      onTap: selected || locked ? null : onApply,
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Não foi possível carregar os temas'),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
