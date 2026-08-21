import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/report_provider.dart';
import '../../core/providers/subscription_provider.dart';
import 'plans_page.dart';

class ReportSettingsPage extends ConsumerStatefulWidget {
  const ReportSettingsPage({super.key});

  @override
  ConsumerState<ReportSettingsPage> createState() => _ReportSettingsPageState();
}

class _PrefsSnapshot {
  final bool enabled;
  final int day;
  final int hourUtc;
  final String reportType;

  const _PrefsSnapshot(this.enabled, this.day, this.hourUtc, this.reportType);

  @override
  bool operator ==(Object other) =>
      other is _PrefsSnapshot &&
      other.enabled == enabled &&
      other.day == day &&
      other.hourUtc == hourUtc &&
      other.reportType == reportType;

  @override
  int get hashCode => Object.hash(enabled, day, hourUtc, reportType);
}

class _ReportSettingsPageState extends ConsumerState<ReportSettingsPage> {
  static const _monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril',
    'Maio', 'Junho', 'Julho', 'Agosto',
    'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  bool _enabled = true;
  int _day = 1;
  int _hourUtc = 9;
  String _reportType = 'simple';
  bool _isSaving = false;
  bool _isSendingTest = false;
  bool _initialized = false;
  _PrefsSnapshot? _saved;

  static int get _tzOffsetHours =>
      (DateTime.now().timeZoneOffset.inMinutes / 60).round();

  static int _utcFromLocal(int localHour) =>
      ((localHour - _tzOffsetHours) % 24 + 24) % 24;

  static int _localFromUtc(int utcHour) =>
      ((utcHour + _tzOffsetHours) % 24 + 24) % 24;

  static String _hourLabel(int hourUtc) =>
      '${_localFromUtc(hourUtc).toString().padLeft(2, '0')}:00';

  _PrefsSnapshot get _snapshot =>
      _PrefsSnapshot(_enabled, _day, _hourUtc, _reportType);

  bool get _dirty => _saved != null && _saved != _snapshot;

  bool get _isPremium => ref.watch(subscriptionProvider).value?.isActive == true;

  bool get _premiumNow => ref.read(subscriptionProvider).value?.isActive == true;

  Map<String, dynamic>? _lastPrefs;

  void _openPlans() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlansPage()),
    );
  }

  Widget _premiumBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.shade700.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 12, color: Colors.amber.shade700),
            const SizedBox(width: 4),
            Text(
              'Premium',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade700,
              ),
            ),
          ],
        ),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    ref.listen(reportPreferencesProvider, (prev, next) {
      final prefs = next.value;
      if (prefs == null) return;
      _lastPrefs = prefs;
      if (!mounted || _dirty) return;
      _applyPrefs(prefs);
    });
    ref.listen(subscriptionProvider, (prev, next) {
      if (!mounted || _dirty || _lastPrefs == null) return;
      _applyPrefs(_lastPrefs!);
    });
  }

  @override
  void initState() {
    super.initState();
    final cached = ref.read(reportPreferencesProvider).value;
    if (cached != null) {
      _lastPrefs = cached;
      _applyPrefs(cached);
    }
  }

  void _applyPrefs(Map<String, dynamic> prefs) {
    setState(() {
      _enabled = prefs['email_reports_enabled'] as bool? ?? true;
      _day = prefs['report_day'] as int? ?? 1;
      _hourUtc = prefs['report_hour'] as int? ?? _utcFromLocal(9);
      _reportType = prefs['report_type'] as String? ?? 'simple';
      _saved = _snapshot;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final type = _premiumNow ? _reportType : 'simple';
    if (type != _reportType) {
      setState(() => _reportType = type);
    }
    await ref.read(reportActionsProvider).save(
          emailReportsEnabled: _enabled,
          reportDay: _day,
          reportHour: _hourUtc,
          reportType: type,
        );
    if (mounted) {
      setState(() {
        _saved = _snapshot;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferências guardadas'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _isSaving = false;
    }
  }

  Future<void> _sendTest() async {
    final month = await _pickTestMonth();
    if (month == null || !mounted) return;

    setState(() => _isSendingTest = true);
    final ok = await ref.read(reportActionsProvider).sendTest(
          reportType: _reportType,
          month: '${month.year}-${month.month.toString().padLeft(2, '0')}',
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Relatório de teste de ${_monthNames[month.month - 1]} ${month.year} enviado para o teu email'
                : 'Erro ao enviar o relatório de teste',
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
    setState(() => _isSendingTest = false);
  }

  Future<void> _pickSchedule() async {
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) {
        var day = _day;
        var localHour = _localFromUtc(_hourUtc);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Dia e hora do relatório'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dia do mês',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                    children: [
                      for (var d = 1; d <= 28; d++)
                        OutlinedButton(
                          onPressed: () => setDialogState(() => day = d),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: d == day
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            foregroundColor: d == day
                                ? Theme.of(context).colorScheme.onPrimary
                                : null,
                          ),
                          child: Text('$d'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hora',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 24,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton(
                          onPressed: () => setDialogState(() => localHour = i),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            backgroundColor: i == localHour
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            foregroundColor: i == localHour
                                ? Theme.of(context).colorScheme.onPrimary
                                : null,
                          ),
                          child: Text('${i.toString().padLeft(2, '0')}h'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, (day, localHour)),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && mounted) {
      setState(() {
        _day = result.$1;
        _hourUtc = _utcFromLocal(result.$2);
      });
    }
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterações não guardadas'),
        content: const Text(
          'Tens alterações por guardar. Queres sair sem guardar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair sem guardar'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _handleDiscardBack() async {
    if (!await _confirmDiscard()) return;
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleDiscardBack();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Relatórios por Email')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.email_outlined),
              title: const Text('Relatório mensal por email'),
              subtitle:
                  const Text('Recebe um resumo das tuas despesas mensalmente'),
              value: _enabled,
              onChanged: (value) => setState(() {
                _enabled = value;
                if (value && _premiumNow) _reportType = 'detailed';
              }),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.event_repeat),
                    title: Row(
                      children: [
                        const Expanded(child: Text('Dia e hora do envio')),
                        if (!_isPremium) _premiumBadge(),
                      ],
                    ),
                    subtitle: Text('Dia $_day às ${_hourLabel(_hourUtc)}'),
                    onTap: !_enabled
                        ? null
                        : () => _isPremium ? _pickSchedule() : _openPlans(),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.article_outlined),
                    title: Row(
                      children: [
                        const Expanded(child: Text('Relatório detalhado')),
                        if (!_isPremium) _premiumBadge(),
                      ],
                    ),
                    subtitle: Text(
                      _reportType == 'detailed'
                          ? 'Com despesas, categorias e gráficos'
                          : 'Simples · só o resumo',
                    ),
                    value: _reportType == 'detailed',
                    onChanged: !_enabled
                        ? null
                        : (value) {
                            if (!_isPremium) {
                              _openPlans();
                              return;
                            }
                            setState(() =>
                                _reportType = value ? 'detailed' : 'simple');
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isSendingTest ? null : _sendTest,
              icon: _isSendingTest
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('Enviar relatório de teste'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickTestMonth() async {
    var year = DateTime.now().year;
    DateTime? result;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mês do relatório de teste'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setDialogState(() => year--),
                  ),
                  Text(
                    '$year',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setDialogState(() => year++),
                  ),
                ],
              ),
              const Divider(height: 1),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
                children: [
                  for (var m = 1; m <= 12; m++)
                    OutlinedButton(
                      onPressed: () {
                        result = DateTime(year, m);
                        Navigator.pop(context);
                      },
                      child: Text(
                        _monthNames[m - 1],
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result;
  }
}
