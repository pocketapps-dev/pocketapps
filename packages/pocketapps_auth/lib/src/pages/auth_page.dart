import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth_service.dart';

/// Login / sign-up screen shared by all PocketApps apps.
///
/// [onNewUser] is invoked once after a brand new user signs in so the app
/// can seed app-specific data (e.g. default categories).
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, this.onNewUser});

  final Future<void> Function()? onNewUser;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isGoogleInitializing = true;
  bool _privacyAccepted = false;
  bool _ageConfirmed = false;
  String? _googleInitError;

  @override
  void initState() {
    super.initState();
    _initGoogleSignIn();
  }

  Future<void> _initGoogleSignIn() async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: PocketAuth.config.googleServerClientId,
        serverClientId: PocketAuth.config.googleServerClientId,
      );
      debugPrint('GoogleSignIn initialized OK');
    } catch (e) {
      debugPrint('GoogleSignIn initialize FAILED: $e');
      if (mounted) setState(() => _googleInitError = e.toString());
    } finally {
      if (mounted) setState(() => _isGoogleInitializing = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Preenche todos os campos');
      return;
    }

    if (!_isLogin && password != _confirmPasswordController.text) {
      _showError('As palavras-passe nao coincidem');
      return;
    }

    if (!_isLogin && !_privacyAccepted) {
      _showError('Tens de aceitar a Política de Privacidade e os Termos para criar uma conta');
      return;
    }

    if (!_isLogin && !_ageConfirmed) {
      _showError('Tens de confirmar que tens 16 anos ou mais para criar uma conta');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        final hasAccess = await PocketAuth.signInWithEmail(email, password);
        if (!hasAccess) {
          if (mounted) {
            _showError('Nao tens conta nesta app. Cria uma conta.');
          }
          return;
        }
        if (mounted) context.go('/');
      } else {
        try {
          await PocketAuth.signUpWithEmail(
            email,
            password,
            privacyAccepted: _privacyAccepted,
            termsAccepted: _privacyAccepted,
            ageConfirmed: _ageConfirmed,
          );
          if (mounted) context.push('/email-confirmation');
        } on AuthException catch (e) {
          if (e.message.contains('already registered') || e.message.contains('already exists')) {
            final added = await PocketAuth.handleExistingUser(email);
            if (added && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conta encontrada! Faz login.'),
                  backgroundColor: Colors.green,
                ),
              );
              setState(() => _isLogin = true);
            } else if (mounted) {
              _showError('Erro ao adicionar acesso. Tenta novamente.');
            }
          } else {
            rethrow;
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Erro: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      debugPrint('Google auth OK: ${googleUser.email}');

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        if (mounted) _showError('Nao foi possivel obter o token Google');
        return;
      }

      final isNew = await PocketAuth.signInWithGoogle(idToken, null);
      if (isNew) {
        final accepted = await _requestConsentForGoogle();
        if (!accepted) {
          try {
            await PocketAuth.deleteAccount();
          } catch (_) {}
          await PocketAuth.signOut();
          if (mounted) _showError('Precisas de aceitar os Termos e a Política de Privacidade para continuar');
          return;
        }
        await PocketAuth.recordConsent();
        await widget.onNewUser?.call();
      }
      await PocketAuth.sendWelcomeEmail(googleUser.email);
      if (mounted) context.go('/');
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('Google Sign-In cancelado');
      } else {
        debugPrint('GoogleSignInException: ${e.code} ${e.description}');
        if (mounted) _showError('Erro Google: ${e.description ?? e.code}');
      }
    } on AuthException catch (e) {
      debugPrint('Supabase AuthException: ${e.message}');
      if (mounted) _showError(e.message);
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      if (mounted) _showError('Erro ao entrar com Google: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
    );
  }

  Future<bool> _requestConsentForGoogle() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ConsentDialog(
        websiteUrl: PocketAuth.config.websiteUrl,
        primaryColor: PocketAuth.config.primaryColor,
      ),
    );
    return accepted == true;
  }

  Future<void> _openLegalLink(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showError('Nao foi possivel abrir o link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = PocketAuth.config;
    final googleDisabled = _isLoading || _isGoogleInitializing;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(config.appIcon, size: 64, color: config.primaryColor),
              const SizedBox(height: 16),
              Text(
                config.displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                config.tagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              if (_googleInitError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Google Sign-In indisponivel: configuracao em falta',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Palavra-passe',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
              ),
              const SizedBox(height: 16),
              if (!_isLogin) ...[
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar palavra-passe',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _ageConfirmed,
                  onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Tenho 16 anos ou mais',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                CheckboxListTile(
                  value: _privacyAccepted,
                  onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Li e aceito a '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => _openLegalLink('${PocketAuth.config.websiteUrl}/privacy'),
                            child: Text(
                              'Política de Privacidade',
                              style: TextStyle(
                                color: PocketAuth.config.primaryColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' e os '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => _openLegalLink('${PocketAuth.config.websiteUrl}/terms'),
                            child: Text(
                              'Termos de Serviço',
                              style: TextStyle(
                                color: PocketAuth.config.primaryColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/request-reset'),
                    child: const Text('Esqueci-me da password'),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isLogin ? 'Entrar' : 'Criar Conta'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ou', style: TextStyle(color: Colors.grey[500])),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: googleDisabled ? null : _signInWithGoogle,
                icon: _isGoogleInitializing
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        height: 20,
                        errorBuilder: (_, _, _) => const Icon(Icons.g_mobiledata, size: 24),
                      ),
                label: Text(_isGoogleInitializing ? 'A inicializar...' : 'Entrar com Google'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? 'Nao tens conta? Cria agora' : 'Ja tens conta? Entra'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentDialog extends StatefulWidget {
  const _ConsentDialog({required this.websiteUrl, required this.primaryColor});

  final String websiteUrl;
  final Color primaryColor;

  @override
  State<_ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<_ConsentDialog> {
  bool _ageConfirmed = false;
  bool _privacyAccepted = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bem-vindo a PocketApps'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Para criar a tua conta, precisamos do teu consentimento:'),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _ageConfirmed,
              onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Tenho 16 anos ou mais', style: TextStyle(fontSize: 14)),
            ),
            CheckboxListTile(
              value: _privacyAccepted,
              onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Li e aceito a '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () => _open('${widget.websiteUrl}/privacy'),
                        child: Text(
                          'Política de Privacidade',
                          style: TextStyle(
                            color: widget.primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' e os '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () => _open('${widget.websiteUrl}/terms'),
                        child: Text(
                          'Termos de Serviço',
                          style: TextStyle(
                            color: widget.primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Nao aceito'),
        ),
        FilledButton(
          onPressed: (_ageConfirmed && _privacyAccepted) ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Aceitar'),
        ),
      ],
    );
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
