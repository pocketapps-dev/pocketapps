import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/export_provider.dart';

/// Page where the user can export their data (GDPR portability, art. 20.º).
///
/// Offers two formats:
/// - **JSON** — complete export (expenses, categories, subscriptions,
///   report_preferences, monthly_status).
/// - **CSV** — expenses + categories in a spreadsheet-friendly format.
class ExportDataPage extends ConsumerStatefulWidget {
  const ExportDataPage({super.key});

  @override
  ConsumerState<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends ConsumerState<ExportDataPage> {
  bool _isExporting = false;

  Future<void> _export(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_isExporting) return;

    setState(() => _isExporting = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao exportar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.read(exportActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exportar Dados')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.download_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Portabilidade de dados',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Descarrega os teus dados para os poderes transferir '
                    'para outro serviço (art. 20.º RGPD).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'FORMATOS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.data_object),
                  title: const Text('JSON (completo)'),
                  subtitle: const Text(
                    'Despesas, categorias, subscrições, preferências de relatório e estado mensal',
                  ),
                  trailing: _isExporting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isExporting
                      ? null
                      : () => _export(
                          actions.exportJson,
                          'Exportação JSON concluída',
                        ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('CSV (folha de cálculo)'),
                  subtitle: const Text('Despesas e categorias'),
                  trailing: _isExporting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isExporting
                      ? null
                      : () => _export(
                          actions.exportCsv,
                          'Exportação CSV concluída',
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'O ficheiro é gerado no momento e partilhado através da folha '
            'de partilha do teu dispositivo.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
