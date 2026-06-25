import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/app_database.dart';
import '../../data/repositories/drift_repositories.dart';
import '../../data/repositories/repository_interfaces.dart';
import '../../domain/entities/app_settings.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return DriftAppSettingsRepository(ref.watch(appDatabaseProvider));
});

final appSettingsControllerProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(appSettingsRepositoryProvider).loadSettings();
  }

  Future<void> saveClientCardsViewMode(ClientCardsViewMode mode) async {
    await ref.read(appSettingsRepositoryProvider).saveClientCardsViewMode(mode);
    ref.invalidateSelf();
  }

  Future<void> saveZoomMode(AppZoomMode mode) async {
    await ref.read(appSettingsRepositoryProvider).saveZoomMode(mode);
    ref.invalidateSelf();
  }

  Future<void> saveDarkMode(bool enabled) async {
    await ref.read(appSettingsRepositoryProvider).saveDarkMode(enabled);
    ref.invalidateSelf();
  }
}
