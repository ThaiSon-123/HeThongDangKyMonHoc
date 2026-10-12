import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu access/refresh token.
/// Mobile: Keychain (iOS) / Keystore (Android). Web: localStorage mã hoá.
class TokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> save({String? accessToken, String? refreshToken}) async {
    if (accessToken != null) {
      await _storage.write(key: _accessKey, value: accessToken);
    }
    if (refreshToken != null) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
