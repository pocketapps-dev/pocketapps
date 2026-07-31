import 'package:flutter/material.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';

final appAuthConfig = AuthConfig(
  appName: 'fuel',
  displayName: 'PocketFuel',
  supabaseUrl: 'https://vlbhnlzqixmxtlpqsggd.supabase.co',
  supabaseAnonKey:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsYmhubHpxaXhteHRscHFzZ2dkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwMDIwOTgsImV4cCI6MjEwMDU3ODA5OH0.dEW_iveXfysP6bH33zZvyMPYtv_Ci2qUO4WUvSJYBIw',
  emailRedirectUri: 'pt.pocketapps.pocketfuel://auth-callback',
  websiteUrl: 'https://pocketapps.pt',
  supportEmail: 'geral@pocketapps.pt',
  googleServerClientId: '',
  primaryColor: const Color(0xFF10B981),
  appIcon: Icons.local_gas_station,
  tagline: 'Controla os teus abastecimentos e despesas com combustível.',
);
