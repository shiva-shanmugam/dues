import 'package:dues/data/database/app_database.dart';

class LocalSettingsService {
  LocalSettingsService(this.database);

  final AppDatabase database;

  Future<String> getString(String key, {required String fallback}) async {
    final row = await (database.select(
      database.appSettings,
    )..where((item) => item.key.equals(key))).getSingleOrNull();
    return row?.value ?? fallback;
  }

  Future<void> setString(String key, String value) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  Future<bool> getBool(String key, {bool fallback = false}) async {
    final row = await (database.select(
      database.appSettings,
    )..where((item) => item.key.equals(key))).getSingleOrNull();
    return row == null ? fallback : row.value == 'true';
  }

  Future<void> setBool(String key, {required bool value}) {
    return database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value.toString()),
        );
  }
}
