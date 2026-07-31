import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';

import 'config/app_config.dart';
import 'config/theme.dart';
import 'config/theme_provider.dart';
import 'config/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await PocketAuth.initialize(appAuthConfig);
  await initializeDateFormatting('pt_PT');

  runApp(const ProviderScope(child: PocketExpensesApp()));
}

class PocketExpensesApp extends ConsumerWidget {
  const PocketExpensesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: PocketAuth.config.displayName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
