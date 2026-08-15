import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';

class SettingsStore {
  SettingsStore(this._preferences);

  static const String _key = 'app_settings_v1';
  final SharedPreferences _preferences;

  static Future<SettingsStore> create() async =>
      SettingsStore(await SharedPreferences.getInstance());

  AppSettings load() {
    final String? encoded = _preferences.getString(_key);
    if (encoded == null) {
      return const AppSettings();
    }
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is Map<String, Object?>) {
        return AppSettings.fromJson(decoded);
      }
    } on FormatException {
      return const AppSettings();
    }
    return const AppSettings();
  }

  Future<void> save(AppSettings settings) async {
    await _preferences.setString(_key, jsonEncode(settings.toJson()));
  }
}
