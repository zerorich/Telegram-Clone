import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, bool>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(true) {
    _load();
  }

  static const _key = 'dark_mode';

  Future<void> _load() async {
    final box = await Hive.openBox('settings');
    state = box.get(_key, defaultValue: true) as bool;
  }

  Future<void> toggle() async {
    state = !state;
    final box = await Hive.openBox('settings');
    await box.put(_key, state);
  }

  Future<void> setDark(bool dark) async {
    state = dark;
    final box = await Hive.openBox('settings');
    await box.put(_key, dark);
  }
}
