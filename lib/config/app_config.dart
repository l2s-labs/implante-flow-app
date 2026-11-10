import 'dart:io';

class AppConfig {
  const AppConfig._();

  static const workOsClientId = String.fromEnvironment('WORKOS_CLIENT_ID');

  static const workOsRedirectUri = String.fromEnvironment(
    'WORKOS_REDIRECT_URI',
    defaultValue: 'com.l2slabs.implanteflow://auth/callback',
  );

  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Emulador Android fala com a máquina em `10.0.2.2`. Simulador iOS e desktop usam `127.0.0.1`.
  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://127.0.0.1:3000';
  }
}
