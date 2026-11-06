import 'package:dues/data/services/local_settings_service.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppPreferences {
  const AppPreferences({
    this.currency = 'INR',
    this.hapticsEnabled = true,
    this.renewalAlertsEnabled = true,
  });

  final String currency;
  final bool hapticsEnabled;
  final bool renewalAlertsEnabled;

  AppPreferences copyWith({
    String? currency,
    bool? hapticsEnabled,
    bool? renewalAlertsEnabled,
  }) => AppPreferences(
    currency: currency ?? this.currency,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    renewalAlertsEnabled: renewalAlertsEnabled ?? this.renewalAlertsEnabled,
  );
}

class AppPreferencesController extends AsyncNotifier<AppPreferences> {
  @override
  Future<AppPreferences> build() async {
    final settings = ref.watch(localSettingsProvider);
    return AppPreferences(
      currency: await settings.getString('currency', fallback: 'INR'),
      hapticsEnabled: await settings.getBool('hapticsEnabled', fallback: true),
      renewalAlertsEnabled: await settings.getBool(
        'renewalAlertsEnabled',
        fallback: true,
      ),
    );
  }

  Future<void> _update(
    Future<void> Function(LocalSettingsService) save,
    AppPreferences Function(AppPreferences) update,
  ) async {
    final current = await future;
    await save(ref.read(localSettingsProvider));
    state = AsyncData(update(current));
  }

  Future<void> setCurrency(String value) => _update(
    (settings) => settings.setString('currency', value),
    (current) => current.copyWith(currency: value),
  );

  Future<void> setHapticsEnabled(bool value) => _update(
    (settings) => settings.setBool('hapticsEnabled', value: value),
    (current) => current.copyWith(hapticsEnabled: value),
  );

  Future<void> setRenewalAlertsEnabled(bool value) => _update(
    (settings) => settings.setBool('renewalAlertsEnabled', value: value),
    (current) => current.copyWith(renewalAlertsEnabled: value),
  );
}

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
    );

class AppHaptics {
  const AppHaptics(this.enabled);
  final bool enabled;

  Future<void> selectionClick() async {
    if (enabled) await HapticFeedback.selectionClick();
  }

  Future<void> mediumImpact() async {
    if (enabled) await HapticFeedback.mediumImpact();
  }
}

final hapticsProvider = Provider(
  (ref) => AppHaptics(
    ref.watch(appPreferencesProvider).value?.hapticsEnabled ?? false,
  ),
);

final ignoredMerchantsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(repositoryProvider).watchIgnoredMerchants(),
);
