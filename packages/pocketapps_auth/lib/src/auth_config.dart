import 'package:flutter/material.dart';

/// Per-app authentication configuration.
///
/// Each PocketApps app provides its own [AuthConfig] at startup via
/// [PocketAuth.initialize].
class AuthConfig {
  /// Backend identifier that scopes data per app (e.g. 'expenses', 'fuel').
  final String appName;

  /// Human friendly name shown in the UI (e.g. 'PocketExpenses').
  final String displayName;

  /// Supabase project URL.
  final String supabaseUrl;

  /// Supabase publishable (anon) key.
  final String supabaseAnonKey;

  /// Deep link used for auth callbacks, e.g.
  /// 'pt.pocketapps.pocketexpenses://auth-callback'.
  final String emailRedirectUri;

  /// Company/public website.
  final String websiteUrl;

  /// Support email address.
  final String supportEmail;

  /// Google OAuth client id used by google_sign_in.
  final String googleServerClientId;

  /// Brand color used by the auth screens.
  final Color primaryColor;

  /// Icon shown on the auth screen.
  final IconData appIcon;

  /// Short tagline shown under the app name on the auth screen.
  final String tagline;

  const AuthConfig({
    required this.appName,
    required this.displayName,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.emailRedirectUri,
    required this.websiteUrl,
    required this.supportEmail,
    required this.googleServerClientId,
    this.primaryColor = const Color(0xFF6366F1),
    this.appIcon = Icons.account_balance_wallet,
    this.tagline = 'Gere tudo de forma simples',
  });
}
