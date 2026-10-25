import 'package:shared_preferences/shared_preferences.dart';

enum StorageMode { local, cloud }

class StoragePreferenceService {
  static const String _modeKey = 'storage_mode_v1';
  static const String _chosenKey = 'storage_mode_has_chosen_v1';

  static Future<StorageMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_modeKey);
    return val == 'cloud' ? StorageMode.cloud : StorageMode.local;
  }

  static Future<void> setMode(StorageMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode == StorageMode.cloud ? 'cloud' : 'local');
    await prefs.setBool(_chosenKey, true);
  }

  static Future<bool> isCloud() async {
    return (await getMode()) == StorageMode.cloud;
  }

  static Future<bool> hasChosenMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chosenKey) ?? false;
  }

  static Future<void> resetChoice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chosenKey);
  }
}
