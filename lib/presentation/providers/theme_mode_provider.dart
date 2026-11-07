import 'package:dues/presentation/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  static const _settingKey = 'themeMode';

  @override
  Future<ThemeMode> build() async {
    final saved = await ref
        .watch(localSettingsProvider)
        .getString(_settingKey, fallback: ThemeMode.system.name);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    await ref.read(localSettingsProvider).setString(_settingKey, mode.name);
    state = AsyncData(mode);
  }
}

final themeModeProvider = AsyncNotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
