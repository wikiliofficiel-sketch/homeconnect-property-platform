import 'package:flutter_test/flutter_test.dart';
import 'package:homeconnect/config/app_secrets.dart';

void main() {
  group('AppSecrets', () {
    test('fedapayKey a une valeur par défaut non vide', () {
      expect(AppSecrets.fedapayKey, isNotEmpty);
    });

    test('fedapayEnv est sandbox par défaut', () {
      expect(AppSecrets.fedapayEnv, 'sandbox');
    });

    test('isProduction est false en sandbox', () {
      expect(AppSecrets.isProduction, false);
    });

    test('apiBaseUrl a une valeur par défaut non vide', () {
      expect(AppSecrets.apiBaseUrl, isNotEmpty);
    });

    test('apiBaseUrl par défaut commence par http://', () {
      expect(AppSecrets.apiBaseUrl, startsWith('http://'));
    });
  });
}
