import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'legal_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o link. Tenta novamente.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sobre')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          Icon(
            Icons.account_balance_wallet,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'PocketExpenses',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Versão $_version ($_buildNumber)',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Termos de Serviço'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LegalPage(
                          title: 'Termos de Serviço',
                          icon: Icons.description_outlined,
                          description:
                              'Resumo dos Termos de Serviço da PocketExpenses.',
                          points: [
                            'A PocketExpenses destina-se à gestão pessoal de '
                                'despesas recorrentes e únicas.',
                            'És responsável por manter a tua conta e '
                                'credenciais em segurança.',
                            'O plano Free é gratuito. O Premium é uma subscrição '
                                'anual (€14.99/ano) e o Founder é um pagamento '
                                'único por app (€25, com 50% OFF em lançamento). '
                                'Ambos são ativados mediante código de ativação.',
                            'É proibido usar o serviço para fins ilegais ou '
                                'para violar direitos de terceiros.',
                            'Os teus dados podem ser exportados ou eliminados '
                                'a qualquer momento a partir da conta.',
                            'O serviço é fornecido "como está", podendo ser '
                                'atualizado ou descontinuado com aviso prévio.',
                          ],
                          websiteUrl: 'https://pocketapps.pt/terms',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Política de Privacidade'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LegalPage(
                          title: 'Política de Privacidade',
                          icon: Icons.privacy_tip_outlined,
                          description:
                              'Resumo da Política de Privacidade da '
                              'PocketExpenses.',
                          points: [
                            'Recolhemos apenas os dados necessários: email, '
                                'nome de utilizador, despesas e preferências.',
                            'Os dados são usados para autenticação, '
                                'sincronização e relatórios por email.',
                            'Os dados são armazenados de forma segura em '
                                'servidores na cloud.',
                            'Não partilhamos os teus dados com terceiros para '
                                'fins de publicidade.',
                            'Podes exercer os teus direitos RGPD: acesso, '
                                'retificação, portabilidade e eliminação.',
                            'Para questões, contacta geral@pocketapps.pt.',
                          ],
                          websiteUrl: 'https://pocketapps.pt/privacy',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Contacto'),
                  subtitle: const Text('geral@pocketapps.pt'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openUrl(context, 'mailto:geral@pocketapps.pt'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('PocketApps'),
                  subtitle: const Text('pocketapps.pt'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openUrl(context, 'https://pocketapps.pt'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Feito com ♥ em Portugal',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
