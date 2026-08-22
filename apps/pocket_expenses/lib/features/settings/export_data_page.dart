import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/backup_provider.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/expense_provider.dart';
import '../../core/providers/export_provider.dart';
import '../../core/providers/subscription_provider.dart';
import '../../core/services/backup_service.dart';
import 'plans_page.dart';

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
          const _CloudBackupSection(),
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

class _CloudBackupSection extends ConsumerStatefulWidget {
  const _CloudBackupSection();

  @override
  ConsumerState<_CloudBackupSection> createState() =>
      _CloudBackupSectionState();
}

class _CloudBackupSectionState extends ConsumerState<_CloudBackupSection> {
  bool _busy = false;
  late Future<List<BackupSnapshot>> _snapshotsFuture;

  @override
  void initState() {
    super.initState();
    _snapshotsFuture = ref.read(backupServiceProvider).listSnapshots();
  }

  void _refresh() {
    setState(() {
      _snapshotsFuture = ref.read(backupServiceProvider).listSnapshots();
    });
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _createNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).createBackupNow();
      _refresh();
      _showSnack('Backup criado com sucesso');
    } catch (e) {
      _showSnack('Erro ao criar backup: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(BackupSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar backup?'),
        content: Text(
          'Os teus dados atuais vão ser atualizados com o conteúdo do '
          'backup de ${_formatDate(snapshot.fileName)}.\n\n'
          'Despesas ou categorias apagadas desde então vão voltar a aparecer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy) return;

    setState(() => _busy = true);
    try {
      final result =
          await ref.read(backupServiceProvider).restore(snapshot.fileName);
      ref.invalidate(categoriesProvider);
      ref.invalidate(expensesProvider);
      ref.invalidate(monthlyStatusesProvider);
      _refresh();
      _showSnack(
        'Dados restaurados: ${result.expenses} despesas, '
        '${result.categories} categorias',
      );
    } catch (e) {
      _showSnack('Erro ao restaurar: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatDate(String fileName) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})\.json$').firstMatch(fileName);
    if (m == null) return fileName;
    return '${m.group(3)!}/${m.group(2)!}/${m.group(1)!}';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final isPremium =
        ref.watch(subscriptionProvider).asData?.value?.isActive == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.backup_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'BACKUP NA CLOUD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: isPremium
              ? Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.backup_outlined),
                      title: const Text('Fazer backup agora'),
                      subtitle: const Text(
                        'Guarda um snapshot dos teus dados nos servidores',
                      ),
                      trailing: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      onTap: _busy ? null : _createNow,
                    ),
                    const Divider(height: 1),
                    FutureBuilder<List<BackupSnapshot>>(
                      future: _snapshotsFuture,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done &&
                            !snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        if (snap.hasError) {
                          return ListTile(
                            enabled: false,
                            leading: const Icon(Icons.error_outline),
                            title: const Text('Erro ao carregar backups'),
                          );
                        }
                        final snapshots = snap.data ?? [];
                        if (snapshots.isEmpty) {
                          return const ListTile(
                            enabled: false,
                            leading: Icon(Icons.cloud_off_outlined),
                            title: Text('Ainda sem backups'),
                            subtitle: Text(
                              'O primeiro backup automático é feito à noite',
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final s in snapshots) ...[
                              ListTile(
                                leading: const Icon(
                                  Icons.history,
                                ),
                                title: Text(_formatDate(s.fileName)),
                                subtitle: Text(_formatSize(s.sizeBytes)),
                                trailing: const Icon(Icons.restore),
                                onTap: _busy ? null : () => _restore(s),
                              ),
                              if (s != snapshots.last)
                                const Divider(height: 1),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                )
              : ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Backup na cloud'),
                  subtitle: const Text('Disponível no plano Premium'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlansPage()),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          isPremium
              ? 'Snapshot diário automático. Guardamos os últimos 30 dias; '
                  'podes restaurar qualquer um deles em segundos.'
              : 'No Premium guardamos um snapshot diário automático dos teus '
                  'dados durante 30 dias.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
