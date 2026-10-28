import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/location.dart';
import '../l10n/app_strings.dart';

/// 本地持久化门面。
///
/// 只持久化「用户偏好 + 最近搜索 + 上次地点」，天气数据不落盘：
/// 天气时效性短，持久化收益低于引入数据库的成本。
class PreferencesStore {
  PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _kUnits = 'pref_units';
  static const String _kLocale = 'pref_locale';
  static const String _kLastLocation = 'pref_last_location';
  static const String _kRecentLocations = 'pref_recent_locations';

  UnitSystem readUnits() => UnitSystem.fromName(_prefs.getString(_kUnits));

  Future<void> writeUnits(UnitSystem units) =>
      _prefs.setString(_kUnits, units.name);

  /// 用户选择的语言；null 表示跟随系统。
  Locale? readAppLocale() {
    return switch (_prefs.getString(_kLocale)) {
      'zh-Hans' => zhHansLocale,
      'zh-Hant' => zhHantLocale,
      'en' => enLocale,
      _ => null,
    };
  }

  Future<void> writeAppLocale(Locale? locale) async {
    if (locale == null) {
      await _prefs.remove(_kLocale);
      return;
    }
    await _prefs.setString(_kLocale, locale.toLanguageTag());
  }

  Location? readLastLocation() =>
      _decodeLocation(_prefs.getString(_kLastLocation));

  Future<void> writeLastLocation(Location? location) async {
    if (location == null) {
      await _prefs.remove(_kLastLocation);
      return;
    }
    await _prefs.setString(_kLastLocation, jsonEncode(location.toJson()));
  }

  List<Location> readRecentLocations() {
    final raw = _prefs.getStringList(_kRecentLocations);
    if (raw == null) return const <Location>[];
    final result = <Location>[];
    for (final item in raw) {
      final location = _tryDecode(item);
      if (location != null) result.add(location);
    }
    return result;
  }

  Future<void> writeRecentLocations(List<Location> locations) async {
    final raw = locations
        .map((Location location) => jsonEncode(location.toJson()))
        .toList(growable: false);
    await _prefs.setStringList(_kRecentLocations, raw);
  }

  Location? _decodeLocation(String? raw) {
    if (raw == null) return null;
    return _tryDecode(raw);
  }

  Location? _tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return Location.tryFromJson(decoded);
    } on FormatException {
      return null;
    }
  }
}
