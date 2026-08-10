import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'config/currency_provider.dart';
import 'config/theme.dart';
import 'config/theme_provider.dart';
import 'config/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await PocketAuth.initialize(appAuthConfig);
  await initializeDateFormatting('pt_PT');

  final prefs = await SharedPreferences.getInstance();
  final currency = prefs.getString(currencyPrefKey) ?? 'EUR';
  final themeName =
      AppTheme.normalizeThemeName(prefs.getString(themeNamePrefKey) ?? 'Light');
  final themeMode = AppTheme.getBrightness(themeName) == Brightness.dark
      ? ThemeMode.dark
      : ThemeMode.light;

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(
          () => ThemeModeNotifier(
            initial: themeMode,
          ),
        ),
        themeNameProvider.overrideWith(
          () => ThemeNameNotifier(initial: themeName),
        ),
        currencyProvider.overrideWith(
          () => CurrencyNotifier(initial: currency),
        ),
      ],
      child: const PocketExpensesApp(),
    ),
  );
}

class PocketExpensesApp extends ConsumerWidget {
  const PocketExpensesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themeName = ref.watch(themeNameProvider);

    final lightTheme = AppTheme.getTheme(themeName, Brightness.light);
    final darkTheme = AppTheme.getTheme(themeName, Brightness.dark);

    return MaterialApp.router(
      title: PocketAuth.config.displayName,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
