import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';

import '../calendar/calendar_page.dart';
import '../expenses/expenses_page.dart';
import 'dashboard_tab.dart';
import '../settings/settings_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  final _keys = List.generate(4, (_) => UniqueKey());
  bool _checkingAccess = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final hasAccess = await PocketAuth.checkAppAccess();
      if (!hasAccess && mounted) {
        await PocketAuth.signOut();
        if (mounted) context.go('/auth');
        return;
      }
    } catch (e) {
      if (mounted) {
        await PocketAuth.signOut();
        if (mounted) context.go('/auth');
        return;
      }
    }
    if (mounted) setState(() => _checkingAccess = false);
  }

  void _refreshAll() {
    setState(() {
      for (var i = 0; i < _keys.length; i++) {
        _keys[i] = UniqueKey();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardTab(key: _keys[0], onRefresh: _refreshAll),
          ExpensesPage(key: _keys[1]),
          CalendarPage(key: _keys[2]),
          SettingsPage(key: _keys[3]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() {
            if (i == 0 || i == 2) {
              _keys[i] = UniqueKey();
            }
            _currentIndex = i;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Despesas'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Definicoes'),
        ],
      ),
    );
  }
}
