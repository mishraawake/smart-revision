import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

/// Which Firebase project the app talks to. One build holds both; the
/// choice is saved on the phone and applied at startup.
enum AppEnv { staging, prod }

abstract final class Environment {
  static const _key = 'env.v1';

  /// Typed into the hidden switch. It only keeps the menu out of curious
  /// hands; staging holds test data, so it guards nothing valuable.
  static const switchCode = '2580';

  /// Null until [init] runs, as in widget tests, which never touch Firebase.
  static AppEnv? current;

  static bool get isStaging => current == AppEnv.staging;

  /// Release builds start on prod, debug builds on staging, until someone
  /// picks otherwise.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    current = saved == null
        ? (kReleaseMode ? AppEnv.prod : AppEnv.staging)
        : AppEnv.values.byName(saved);
    await Firebase.initializeApp(options: _options(current!));
  }

  static FirebaseOptions _options(AppEnv env) => switch ((env, kIsWeb)) {
    (AppEnv.staging, true) => FirebaseEnvOptions.stagingWeb,
    (AppEnv.staging, false) => FirebaseEnvOptions.stagingAndroid,
    (AppEnv.prod, true) => FirebaseEnvOptions.prodWeb,
    (AppEnv.prod, false) => FirebaseEnvOptions.prodAndroid,
  };

  /// Wipes this phone's data so nothing crosses between projects, saves the
  /// choice and closes the app; it starts on [env] when reopened.
  static Future<void> switchTo(AppEnv env) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString(_key, env.name);
    await SystemNavigator.pop();
  }
}
