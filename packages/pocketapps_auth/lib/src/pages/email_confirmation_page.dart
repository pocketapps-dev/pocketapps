import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth_service.dart';

/// Shown after email sign-up. Waits for the confirmation email flow and
/// invokes [onNewUser] so the app can seed data for new users.
class EmailConfirmationPage extends ConsumerStatefulWidget {
  const EmailConfirmationPage({super.key, this.onNewUser});

  final Future<void> Function()? onNewUser;

  @override
  ConsumerState<EmailConfirmationPage> createState() => _EmailConfirmationPageState();
}

class _EmailConfirmationPageState extends ConsumerState<EmailConfirmationPage> {
  @override
  void initState() {
    super.initState();
    _listenForConfirmation();
  }

  void _listenForConfirmation() {
    PocketAuth.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        widget.onNewUser?.call();
        if (mounted) {
          context.go('/');
        }
      }
    });
  }

  Future<void> _openEmailApp() async {
    final gmailUri = Uri.parse('content://com.google.android.gm/label/INBOX');
    try {
      if (await canLaunchUrl(gmailUri)) {
        await launchUrl(gmailUri);
        return;
      }
    } catch (_) {}

    final mailtoUri = Uri.parse('mailto:');
    try {
      await launchUrl(mailtoUri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abre a tua app de email manualmente')),
        );
      }
    }
  }

  void _closeApp() {
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.mark_email_read, size: 80, color: PocketAuth.config.primaryColor),
              const SizedBox(height: 32),
              Text(
                'Conta criada com sucesso!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enviámos um email de confirmação.\nAbre a tua caixa de entrada e clica no link de confirmação.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _openEmailApp,
                icon: const Icon(Icons.email_outlined),
                label: const Text('Abrir Email'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _closeApp,
                child: const Text('Fechar App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
