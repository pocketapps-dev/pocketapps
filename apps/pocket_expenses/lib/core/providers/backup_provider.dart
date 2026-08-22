import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(Supabase.instance.client);
});
