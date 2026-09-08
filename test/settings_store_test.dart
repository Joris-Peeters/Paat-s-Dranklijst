import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/settings/settings_data.dart';
import 'package:paats_dranklijst/settings/settings_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsStore store;

  Future<void> openEmpty() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
  }

  Future<void> openWith(Map<String, Object> data) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(data);
    store = await SettingsStore.open();
  }

  setUp(openEmpty);

  test('an empty store reads as the defaults', () {
    expect(store.read(), const AppSettingsData());
  });

  test('every field survives a round trip', () async {
    final written = AppSettingsData(
      themeMode: AppThemeMode.dark,
      darkStart: const TimeOfDay(hour: 21, minute: 30),
      darkEnd: const TimeOfDay(hour: 6, minute: 15),
      seedColorArgb: 0xFF123456,
      languageCode: 'nl',
      currencyCode: 'USD',
      allowSelfRegistration: false,
      adminPin: '1234',
      payeeName: 'Chiro Paat',
      payeeIban: 'BE68539007547034',
      // Seconds precision is all the epoch round trip needs to prove.
      setupCompletedAt: DateTime(2026, 9, 8, 21, 30),
    );

    await store.save(written);

    // A second store over the same backing data, so this reads persisted
    // values rather than anything cached from the write.
    final reopened = await SettingsStore.open();
    expect(reopened.read(), written);
  });

  test('clearing a nullable field removes it', () async {
    await store.save(
      const AppSettingsData().copyWith(
        adminPin: '1234',
        payeeName: 'Chiro',
        payeeIban: 'BE68539007547034',
        setupCompletedAt: DateTime(2026),
      ),
    );
    expect((await SettingsStore.open()).read().adminPin, '1234');

    await store.save(const AppSettingsData());

    final cleared = (await SettingsStore.open()).read();
    expect(cleared.adminPin, isNull);
    expect(cleared.payeeName, isNull);
    expect(cleared.payeeIban, isNull);
    expect(cleared.setupCompletedAt, isNull);
  });

  test('an unrecognized themeMode falls back to the default', () async {
    await openWith({'themeMode': 'sepia'});
    expect(store.read().themeMode, const AppSettingsData().themeMode);
  });

  test('a partially written store fills the gaps with defaults', () async {
    await openWith({'languageCode': 'nl', 'seedColorArgb': 0xFF123456});

    final settings = store.read();
    expect(settings.languageCode, 'nl');
    expect(settings.seedColorArgb, 0xFF123456);
    expect(settings.currencyCode, 'EUR');
    expect(settings.darkStart, const TimeOfDay(hour: 20, minute: 0));
  });
}
