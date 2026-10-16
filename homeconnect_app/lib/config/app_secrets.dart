// Secrets injectés au build via --dart-define
// Usage dev    : flutter run
// Usage prod   : flutter build apk --dart-define=FEDAPAY_KEY=sk_live_xxx --dart-define=API_BASE_URL=https://api.homeconnect.bj --dart-define=FEDAPAY_ENV=production
class AppSecrets {
  static const fedapayKey = String.fromEnvironment(
    'FEDAPAY_KEY',
    defaultValue: 'sk_sandbox_atW7p_6fT6f_4R7f_test',
  );

  static const fedapayEnv = String.fromEnvironment(
    'FEDAPAY_ENV',
    defaultValue: 'sandbox',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static bool get isProduction => fedapayEnv == 'production';
}
