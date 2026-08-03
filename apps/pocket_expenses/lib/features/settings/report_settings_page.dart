import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/report_provider.dart';

class ReportSettingsPage extends ConsumerStatefulWidget {
  const ReportSettingsPage({super.key});

  @override
  ConsumerState<ReportSettingsPage> createState() => _ReportSettingsPageState();
}

class _ReportSettingsPageState extends ConsumerState<ReportSettingsPage> {
  bool _enabled = false;
  int _day = 1;
  int _hour = 9;
  String _reportType = 'detailed';
  bool _includeCategories = true;
  bool _includeCharts = true;
  bool _isSaving = false;
  bool _isSendingTest = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    ref.listen(reportPreferencesProvider, (prev, next) {
      if (!mounted) return;
      final prefs = next.value;
      if (prefs == null) return;
      setState(() {
        _enabled = prefs['email_reports_enabled'] as bool? ?? false;
        _day = prefs['report_day'] as int? ?? 1;
        _hour = prefs['report_hour'] as int? ?? 9;
        _reportType = prefs['report_type'] as String? ?? 'detailed';
        _includeCategories = prefs['include_categories'] as bool? ?? true;
        _includeCharts = prefs['include_charts'] as bool? ?? true;
      });
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await ref.read(reportActionsProvider).save(
          emailReportsEnabled: _enabled,
          reportDay: _day,
          reportHour: _hour,
          includeCategories: _includeCategories,
          includeCharts: _includeCharts,
          reportType: _reportType,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferências guardadas'),
          backgroundColor: Colors.green,
        ),
      );
    }
    setState(() => _isSaving = false);
  }

  Future<void> _sendTest() async {
    setState(() => _isSendingTest = true);
    final ok = await ref.read(reportActionsProvider).sendTest(reportType: _reportType);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Relatório de teste enviado para o teu email'
                : 'Erro ao enviar o relatório de teste',
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
    setState(() => _isSendingTest = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios por Email')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.email_outlined),
            title: const Text('Relatório mensal por email'),
            subtitle: const Text('Recebe um resumo das tuas despesas mensalmente'),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Dia do relatório'),
                  trailing: Text('Dia $_day'),
                  onTap: _enabled
                      ? () async {
                          final selected = await _pickDay();
                          if (selected != null) setState(() => _day = selected);
                        }
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Hora'),
                  trailing: Text('${_hour.toString().padLeft(2, '0')}:00'),
                  onTap: _enabled
                      ? () async {
                          final selected = await _pickHour();
                          if (selected != null) setState(() => _hour = selected);
                        }
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Tipo de relatório'),
                  subtitle: Text(
                    _reportType == 'simple'
                        ? 'Simples · só o resumo'
                        : 'Detalhado · com categorias e gráficos',
                  ),
                  onTap: _enabled
                      ? () async {
                          final selected = await _pickReportType();
                          if (selected != null) setState(() => _reportType = selected);
                        }
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.category_outlined),
                  title: const Text('Incluir despesas por categoria'),
                  value: _includeCategories,
                  onChanged: _enabled
                      ? (value) => setState(() => _includeCategories = value)
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.pie_chart_outline),
                  title: const Text('Incluir gráficos'),
                  value: _includeCharts,
                  onChanged: _enabled
                      ? (value) => setState(() => _includeCharts = value)
                      : null,
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
    );
  }

  Future<int?> _pickDay() async {
    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Dia do relatório'),
        children: [
          for (var d = 1; d <= 28; d++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, d),
              child: Text('Dia $d'),
            ),
        ],
      ),
    );
  }

  Future<int?> _pickHour() async {
    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Hora do relatório'),
        children: [
          for (var h = 0; h < 24; h++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, h),
              child: Text('${h.toString().padLeft(2, '0')}:00'),
            ),
        ],
      ),
    );
  }

  Future<String?> _pickReportType() async {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Tipo de relatório'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'simple'),
            child: const Text('Simples · só o resumo'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'detailed'),
            child: const Text('Detalhado · com categorias e gráficos'),
          ),
        ],
      ),
    );
  }
}
