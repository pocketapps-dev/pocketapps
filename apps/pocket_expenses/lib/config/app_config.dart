import 'package:flutter/material.dart';
import 'package:pocketapps_auth/pocketapps_auth.dart';

/// App-specific [AuthConfig] for PocketExpenses.
final appAuthConfig = AuthConfig(
  appName: 'expenses',
  displayName: 'PocketExpenses',
  supabaseUrl: 'https://vlbhnlzqixmxtlpqsggd.supabase.co',
  supabaseAnonKey:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsYmhubHpxaXhteHRscHFzZ2dkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwMDIwOTgsImV4cCI6MjEwMDU3ODA5OH0.dEW_iveXfysP6bH33zZvyMPYtv_Ci2qUO4WUvSJYBIw',
  emailRedirectUri: 'pt.pocketapps.pocketexpenses://auth-callback',
  websiteUrl: 'https://pocketapps.pt',
  supportEmail: 'geral@pocketapps.pt',
  googleServerClientId:
      '444888135065-qkch3d0saa3t0cun0j8a06o5v2vpgf6h.apps.googleusercontent.com',
  primaryColor: const Color(0xFF6366F1),
  appIcon: Icons.account_balance_wallet,
  tagline: 'Gere as tuas finanças de forma simples',
);
