import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('shouldAllowDevelopmentDefaultApiBaseUrl', () {
      final config = AppConfig();

      expect(config.environment, AppEnvironment.development);
      expect(config.apiBaseUrl, 'http://10.0.2.2:8080');
    });

    test('shouldAllowDevelopmentLocalApiBaseUrl', () {
      final config = AppConfig(
        apiBaseUrl: 'http://10.0.2.2:8080',
      );

      expect(config.apiBaseUrl, 'http://10.0.2.2:8080');
    });

    test('shouldRequireExplicitProductionApiBaseUrl', () {
      expect(
        () => AppConfig(environment: AppEnvironment.production),
        throwsArgumentErrorWithMessage('MM_API_BASE_URL must not be blank'),
      );
    });

    test('shouldAcceptProductionHttpsApiBaseUrl', () {
      final config = AppConfig(
        apiBaseUrl: 'https://api.memory-story.example',
        environment: AppEnvironment.production,
      );

      expect(config.apiBaseUrl, 'https://api.memory-story.example');
    });

    test('shouldRejectProductionHttpApiBaseUrl', () {
      expect(
        () => AppConfig(
          apiBaseUrl: 'http://api.memory-story.example',
          environment: AppEnvironment.production,
        ),
        throwsArgumentErrorWithMessage(
          'Production MM_API_BASE_URL must use https',
        ),
      );
    });

    test('shouldRejectProductionEmulatorApiBaseUrl', () {
      expect(
        () => AppConfig(
          apiBaseUrl: 'https://10.0.2.2:8080',
          environment: AppEnvironment.production,
        ),
        throwsArgumentErrorWithMessage(
          'Production MM_API_BASE_URL must not use a local development host',
        ),
      );
    });

    test('shouldRejectProductionLocalhostApiBaseUrl', () {
      expect(
        () => AppConfig(
          apiBaseUrl: 'https://localhost:8080',
          environment: AppEnvironment.production,
        ),
        throwsArgumentErrorWithMessage(
          'Production MM_API_BASE_URL must not use a local development host',
        ),
      );
    });

    test('shouldRejectProductionLoopbackApiBaseUrl', () {
      expect(
        () => AppConfig(
          apiBaseUrl: 'https://127.0.0.1:8080',
          environment: AppEnvironment.production,
        ),
        throwsArgumentErrorWithMessage(
          'Production MM_API_BASE_URL must not use a local development host',
        ),
      );
    });

    test('shouldRejectMalformedApiBaseUrl', () {
      expect(
        () => AppConfig(apiBaseUrl: 'not a url'),
        throwsArgumentErrorWithMessage(
          'MM_API_BASE_URL must be an absolute API URL',
        ),
      );
    });

    test('shouldRejectRelativeApiBaseUrl', () {
      expect(
        () => AppConfig(apiBaseUrl: '/api/v1'),
        throwsArgumentErrorWithMessage(
          'MM_API_BASE_URL must be an absolute API URL',
        ),
      );
    });

    test('shouldRequireExplicitLocalPerformanceApiBaseUrl', () {
      expect(
        () => AppConfig(environment: AppEnvironment.localPerformance),
        throwsArgumentErrorWithMessage('MM_API_BASE_URL must not be blank'),
      );
    });

    test('shouldAllowLocalPerformanceHttpLanApiBaseUrl', () {
      final config = AppConfig(
        apiBaseUrl: 'http://192.168.1.10:8080',
        environment: AppEnvironment.localPerformance,
      );

      expect(config.apiBaseUrl, 'http://192.168.1.10:8080');
    });
  });
}

Matcher throwsArgumentErrorWithMessage(String message) {
  return throwsA(
    isA<ArgumentError>().having(
      (error) => error.message,
      'message',
      message,
    ),
  );
}
