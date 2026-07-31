import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const darkModePrefKey = 'dark_mode';

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
