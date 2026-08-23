import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/currency_provider.dart';
import '../../config/theme_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../expenses/expense_wizard_page.dart';
import '../home/home_page.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageCtrl = PageController();
  final _usernameCtrl = TextEditingController();
  int _page = 0;

  static const _totalPages = 6;
  bool _finishing = false;

  String _currency = 'EUR';
  ThemeMode _themeMode = ThemeMode.light;
  String? _originalUsername;

  @override
  void initState() {
    super.initState();
    ref.read(profileProvider.future).then((profile) {
      if (!mounted) return;
      final current = profile?['username']?.toString() ?? '';
      setState(() {
        _usernameCtrl.text = current;
        _originalUsername = current;
      });
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish({bool useWizard = false}) async {
    if (_finishing) return;
    _finishing = true;

    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) {
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O nome de utilizador não pode estar vazio'),
        ),
      );
      return;
    }
    if (username != _originalUsername) {
      final ok =
          await ref.read(profileActionsProvider).updateUsername(username);
      if (!ok) {
        setState(() => _finishing = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nome de utilizador já está em uso'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    await ref.read(currencyProvider.notifier).setCurrency(_currency);
    await ref.read(themeModeProvider.notifier).setMode(_themeMode);
    await ref.read(profileActionsProvider).completeOnboarding();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
    if (useWizard && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ExpenseWizardPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLast = _page == _totalPages - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: TextButton(
                  onPressed: _finishing ? null : () => _finish(),
                  child: const Text('Saltar'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _SlideWelcome(colorScheme: colorScheme),
                  _SlideRecurring(colorScheme: colorScheme),
                  _SlideSummary(colorScheme: colorScheme),
                  _SlidePreview(colorScheme: colorScheme),
                  _SetupPage(
                    usernameController: _usernameCtrl,
                    currency: _currency,
                    onCurrencyChanged: (c) => setState(() => _currency = c),
                    themeMode: _themeMode,
                    onThemeModeChanged: (m) => setState(() => _themeMode = m),
                    colorScheme: colorScheme,
                  ),
                  _WizardOfferPage(
                    onUseWizard: () => _finish(useWizard: true),
                    onExploreAlone: () => _finish(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _totalPages,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _page ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? colorScheme.primary
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    FilledButton.icon(
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        _page >= _totalPages - 2 ? 'Continuar' : 'Seguinte',
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

class _SlideWelcome extends StatelessWidget {
  final ColorScheme colorScheme;

  const _SlideWelcome({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      icon: Icons.account_balance_wallet_outlined,
      iconColor: colorScheme.primary,
      title: 'Bem-vindo ao PocketExpenses',
      text:
          'Controla todas as tuas despesas fixas e pontuais num so lugar e sabe sempre quanto te sobra no mes.',
    );
  }
}

class _SlideRecurring extends StatelessWidget {
  final ColorScheme colorScheme;

  const _SlideRecurring({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      icon: Icons.event_repeat,
      iconColor: colorScheme.secondary,
      title: 'Despesas recorrentes',
      text:
          'Renda, net, subscricoes... adiciona uma vez e nos avisamos antes de cada pagamento.',
    );
  }
}

class _SlideSummary extends StatelessWidget {
  final ColorScheme colorScheme;

  const _SlideSummary({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      icon: Icons.insights,
      iconColor: colorScheme.tertiary,
      title: 'Resumo e relatorios',
      text:
          'Ve para onde vai o teu dinheiro mes a mes. Com o Premium tens ainda backup na cloud dos teus dados.',
    );
  }
}

class _SlideShell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String text;

  const _SlideShell({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 54, color: iconColor),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SetupPage extends StatelessWidget {
  final TextEditingController usernameController;
  final String currency;
  final ValueChanged<String> onCurrencyChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ColorScheme colorScheme;

  const _SetupPage({
    required this.usernameController,
    required this.currency,
    required this.onCurrencyChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Define as tuas preferencias',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Podes mudar isto depois nas definicoes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 28),
          Text(
            'Nome de utilizador',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.badge_outlined),
              hintText: 'ex.: paulo_silva',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Moeda',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: currencies
                .map(
                  (c) => ChoiceChip(
                    label: Text('${c.code} ${c.symbol}'),
                    selected: currency == c.code,
                    onSelected: (_) => onCurrencyChanged(c.code),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),
          Text(
            'Tema',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Claro'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Escuro'),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) => onThemeModeChanged(s.first),
          ),
        ],
      ),
    );
  }
}

class _WizardOfferPage extends StatelessWidget {
  final VoidCallback onUseWizard;
  final VoidCallback onExploreAlone;

  const _WizardOfferPage({
    required this.onUseWizard,
    required this.onExploreAlone,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, size: 54, color: colorScheme.primary),
          ),
          const SizedBox(height: 32),
          const Text(
            'Criar a tua 1.a despesa?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Text(
            'O Wizard guia-te passo a passo: tipo de despesa, categoria, valor e lembretes. Experimenta gratis agora.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          FilledButton.icon(
            onPressed: onUseWizard,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Sim, guia-me'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onExploreAlone,
            child: const Text('Explorar sozinho'),
          ),
        ],
      ),
    );
  }
}

class _SlidePreview extends StatelessWidget {
  final ColorScheme colorScheme;

  const _SlidePreview({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'A tua pagina principal',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            'Um exemplo do que vais encontrar dentro da app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Agosto 2026',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '1.234,56 € / mes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: 0.62,
                    minHeight: 8,
                    backgroundColor:
                        colorScheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(height: 10),
                _MockTile(
                  icon: Icons.event_repeat,
                  color: colorScheme.secondary,
                  name: 'Renda',
                  sub: 'Fixa · dia 5',
                  amount: '750,00 €',
                ),
                _MockTile(
                  icon: Icons.subscriptions_outlined,
                  color: colorScheme.tertiary,
                  name: 'Netflix',
                  sub: 'Fixa · dia 12',
                  amount: '17,99 €',
                ),
                _MockTile(
                  icon: Icons.shopping_bag_outlined,
                  color: colorScheme.primary,
                  name: 'Compras mercado',
                  sub: 'Variavel',
                  amount: '213,40 €',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final String sub;
  final String amount;

  const _MockTile({
    required this.icon,
    required this.color,
    required this.name,
    required this.sub,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
