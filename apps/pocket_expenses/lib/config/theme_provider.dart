import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const darkModePrefKey = 'dark_mode';
const themeNamePrefKey = 'theme_name';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  ThemeModeNotifier({this.initial = ThemeMode.light});

  final ThemeMode initial;

  @override
  ThemeMode build() => initial;

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(darkModePrefKey, next == ThemeMode.dark);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeNameNotifier extends Notifier<String> {
  ThemeNameNotifier({this.initial = 'Default'});

  final String initial;

  @override
  String build() => initial;

  Future<void> setTheme(String themeName) async {
    state = themeName;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeNamePrefKey, themeName);
  }
}

final themeNameProvider = NotifierProvider<ThemeNameNotifier, String>(
  ThemeNameNotifier.new,
);
