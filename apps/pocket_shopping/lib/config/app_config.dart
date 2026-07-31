import 'package:flutter/material.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';

final appAuthConfig = AuthConfig(
  appName: 'shopping',
  displayName: 'PocketShopping',
  supabaseUrl: 'https://vlbhnlzqixmxtlpqsggd.supabase.co',
  supabaseAnonKey:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsYmhubHpxaXhteHRscHFzZ2dkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwMDIwOTgsImV4cCI6MjEwMDU3ODA5OH0.dEW_iveXfysP6bH33zZvyMPYtv_Ci2qUO4WUvSJYBIw',
  emailRedirectUri: 'pt.pocketapps.pocketshopping://auth-callback',
  websiteUrl: 'https://pocketapps.pt',
  supportEmail: 'geral@pocketapps.pt',
  googleServerClientId: '',
  primaryColor: const Color(0xFFF59E0B),
  appIcon: Icons.shopping_bag,
  tagline: 'Organiza as tuas compras e poupa dinheiro.',
);
