import 'package:flutter/material.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';

import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PocketAuth.initialize(appAuthConfig);
  runApp(const PocketShoppingApp());
}

class PocketShoppingApp extends StatelessWidget {
  const PocketShoppingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: PocketAuth.config.displayName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PocketAuth.config.appIcon,
                size: 64,
                color: PocketAuth.config.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                PocketAuth.config.displayName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text('Em breve', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
