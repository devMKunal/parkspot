import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:parkspot/core/constants/storage_keys.dart';

/// The session's tokens. The refresh token lives in the Keystore/Keychain;
/// the access token only in memory, so it dies with the process.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String? accessToken;

  Future<String?> readRefreshToken() =>
      _storage.read(key: StorageKeys.refreshToken);

  /// Saves a pair from `{ accessToken, refreshToken, ... }`.
  Future<void> save(Map<String, dynamic> tokens) async {
    accessToken = tokens['accessToken'] as String;
    await _storage.write(
      key: StorageKeys.refreshToken,
      value: tokens['refreshToken'] as String,
    );
  }

  Future<void> clear() async {
    accessToken = null;
    await _storage.delete(key: StorageKeys.refreshToken);
  }
}
