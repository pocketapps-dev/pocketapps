import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_config.dart';

/// Global authentication facade shared across all PocketApps apps.
///
/// Each app must call [PocketAuth.initialize] with its own [AuthConfig]
/// before running the app.
class PocketAuth {
  PocketAuth._();

  static AuthConfig? _config;
  static SupabaseClient? _client;

  /// Optional hook called after a brand new user signs up (Google) or
  /// confirms their email. Apps use it to seed app-specific data
  /// (e.g. default categories).
  static Future<void> Function()? onNewUser;

  static AuthConfig get config {
    final c = _config;
    if (c == null) {
      throw StateError('PocketAuth.initialize() must be called first');
    }
    return c;
  }

  static SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw StateError('PocketAuth.initialize() must be called first');
    }
    return c;
  }

  /// Initializes Supabase with the provided [cfg] and stores it globally.
  static Future<void> initialize(AuthConfig cfg) async {
    _config = cfg;
    if (!Supabase.instance.isInitialized) {
      await Supabase.initialize(
        url: cfg.supabaseUrl,
        publishableKey: cfg.supabaseAnonKey,
      );
    }
    _client = Supabase.instance.client;
  }

  /// Checks if the current user has access to this app.
  static Future<bool> checkAppAccess() async {
    final result = await client.rpc(
      'check_app_access',
      params: {'p_app_name': config.appName},
    );
    return result as bool;
  }

  /// Grants an existing user (by email) access to this app.
  static Future<void> addAppAccess(String email) async {
    await client.rpc(
      'add_app_access',
      params: {'p_email': email, 'p_app_name': config.appName},
    );
  }

  /// Sign up with email/password, tagging the user with this app's name.
  ///
  /// [privacyAccepted], [termsAccepted] and [ageConfirmed] are stored in the
  /// user metadata and recorded on the profile by the `handle_new_user`
  /// trigger (GDPR consent evidence).
  static Future<void> signUpWithEmail(
    String email,
    String password, {
    bool privacyAccepted = false,
    bool termsAccepted = false,
    bool ageConfirmed = false,
  }) async {
    await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'app_name': config.appName,
        'privacy_accepted': privacyAccepted,
        'terms_accepted': termsAccepted,
        'age_confirmed': ageConfirmed,
      },
      emailRedirectTo: config.emailRedirectUri,
    );
  }

  /// Records privacy/terms/age consent on the current user's profile.
  static Future<void> recordConsent() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client
        .from('profiles')
        .update({
          'privacy_accepted_at': DateTime.now().toUtc().toIso8601String(),
          'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
          'age_confirmed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
  }

  /// Sign in with email/password and verify access to this app.
  static Future<bool> signInWithEmail(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
    return checkAppAccess();
  }

  /// Sign in with a Google id token.
  ///
  /// If the user doesn't have access to this app yet, access is granted
  /// automatically. Returns `true` when the user was just created.
  static Future<bool> signInWithGoogle(String idToken, String? accessToken) async {
    await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    final user = client.auth.currentUser;
    final isNewUser =
        user != null &&
        (user.lastSignInAt == null ||
            DateTime.parse(user.createdAt)
                    .difference(DateTime.parse(user.lastSignInAt!))
                    .inSeconds
                    .abs() <
                2);

    final hasAccess = await checkAppAccess();
    if (!hasAccess) {
      final email = user?.email;
      if (email != null) {
        await addAppAccess(email);
      }
    }
    return isNewUser;
  }

  /// Handles "user already registered" during signup by granting access.
  static Future<bool> handleExistingUser(String email) async {
    try {
      await addAppAccess(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sends the welcome email via the `send-welcome-email` edge function.
  ///
  /// The edge function deduplicates using the user_app_access table.
  static Future<void> sendWelcomeEmail(String email) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await client.functions.invoke(
        'send-welcome-email',
        body: {
          'user_id': userId,
          'email': email,
          'app_name': config.appName,
        },
      );
    } catch (e) {
      // Best effort - never block auth on a welcome email.
    }
  }

  /// Sign out from Supabase and Google.
  static Future<void> signOut() async {
    await client.auth.signOut();
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.signOut();
      await googleSignIn.disconnect();
    } catch (_) {}
  }

  /// Updates the current user's password.
  static Future<void> changePassword(String newPassword) async {
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Updates the current user's email (triggers a confirmation email).
  static Future<void> changeEmail(String email) async {
    await client.auth.updateUser(UserAttributes(email: email));
  }

  /// Deletes the current user account via the `delete-account` edge function.
  static Future<void> deleteAccount() async {
    final response = await client.functions.invoke('delete-account');
    if (response.data != null) {
      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) {
        throw Exception(data['error']);
      }
    }
  }
}
