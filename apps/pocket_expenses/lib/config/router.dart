import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/category_provider.dart';
import '../features/home/home_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../features/profile/currency_settings_page.dart';
import '../features/settings/about_page.dart';
import '../features/settings/export_data_page.dart';
import '../features/settings/report_settings_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  ref.listen(authStateProvider, (prev, next) {
    next.whenData((authState) {
      if (authState.event == AuthChangeEvent.passwordRecovery) {
        ref.read(isRecoveryFlowProvider.notifier).trigger();
      }
    });
  });

  Future<void> seedNewUser() async {
    await ref.read(categoryActionsProvider).ensureDefaultCategories();
  }

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = PocketAuth.client.auth.currentSession;
      final isLoggedIn = session != null;
      final location = state.matchedLocation;

      if (ref.read(isRecoveryFlowProvider)) {
        ref.read(isRecoveryFlowProvider.notifier).reset();
        return '/set-new-password';
      }

      const publicRoutes = [
        '/auth',
        '/email-confirmation',
        '/auth-callback',
        '/request-reset',
        '/set-new-password',
      ];
      final isPublicRoute = publicRoutes.contains(location);

      if (!isLoggedIn && !isPublicRoute) return '/auth';
      if (isLoggedIn && location == '/auth') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/auth',
        builder: (context, state) => AuthPage(onNewUser: seedNewUser),
      ),
      GoRoute(
        path: '/email-confirmation',
        builder: (context, state) =>
            EmailConfirmationPage(onNewUser: seedNewUser),
      ),
      GoRoute(
        path: '/auth-callback',
        builder: (context, state) => const AuthCallbackPage(),
      ),
      GoRoute(
        path: '/request-reset',
        builder: (context, state) => const RequestResetPage(),
      ),
      GoRoute(
        path: '/set-new-password',
        builder: (context, state) => const SetNewPasswordPage(),
      ),
      GoRoute(
        path: '/profile/change-email',
        builder: (context, state) => const ChangeEmailPage(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: '/profile/currency',
        builder: (context, state) => const CurrencySettingsPage(),
      ),
      GoRoute(
        path: '/profile/change-password',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: '/profile/delete-account',
        builder: (context, state) => const DeleteAccountPage(),
      ),
      GoRoute(
        path: '/settings/reports',
        builder: (context, state) => const ReportSettingsPage(),
      ),
      GoRoute(
        path: '/settings/export',
        builder: (context, state) => const ExportDataPage(),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (context, state) => const AboutPage(),
      ),
    ],
  );
});
