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
  int _page = 0;

  static const _totalPages = 5;
  bool _finishing = false;

  String _currency = 'EUR';
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void dispose() {
    _pageCtrl.dispose();
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
                  _SetupPage(
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
  final String currency;
  final ValueChanged<String> onCurrencyChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ColorScheme colorScheme;

  const _SetupPage({
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
          const SizedBox(height: 32),
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
