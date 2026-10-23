import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// Keeps every profile and its progress on this phone.
class ProfileStore {
  static const _key = 'profiles.v1';
  static const _lastKey = 'lastProfileId';

  Future<List<Profile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return [
      for (final p in jsonDecode(raw) as List)
        Profile.fromJson(p as Map<String, dynamic>),
    ];
  }

  Future<void> saveProfiles(List<Profile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final p in profiles) p.toJson()]),
    );
  }

  Future<String?> loadLastProfileId() async =>
      (await SharedPreferences.getInstance()).getString(_lastKey);

  Future<void> saveLastProfileId(String id) async =>
      (await SharedPreferences.getInstance()).setString(_lastKey, id);
}
