import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keySecurityType = 'security_type'; // none | pin
const _keyPin = 'shannon_pin';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final securityTypeProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_keySecurityType) ?? 'none';
});

class SecurityService {
  final FlutterSecureStorage _storage;

  SecurityService(this._storage);

  Future<void> setSecurityType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySecurityType, type);
  }

  Future<String> getSecurityType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySecurityType) ?? 'none';
  }

  Future<void> savePin(String pin) async {
    await _storage.write(key: _keyPin, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _keyPin);
    return stored == pin;
  }

  Future<void> deletePin() async {
    await _storage.delete(key: _keyPin);
  }
}

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService(ref.watch(secureStorageProvider));
});
