import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((_) {
  return AppConfig.fromEnvironment();
});

enum AppEnvironment {
  development,
  localPerformance,
  production,
}

final class AppConfig {
  factory AppConfig({
    String? apiBaseUrl,
    String googleServerClientId = '',
    String googleIosClientId = '',
    AppEnvironment environment = AppEnvironment.development,
  }) {
    final resolvedApiBaseUrl = apiBaseUrl ??
        switch (environment) {
          AppEnvironment.development => developmentApiBaseUrl,
          AppEnvironment.localPerformance => '',
          AppEnvironment.production => '',
        };

    _validateApiBaseUrl(resolvedApiBaseUrl, environment);

    return AppConfig._(
      apiBaseUrl: resolvedApiBaseUrl.trim(),
      googleServerClientId: googleServerClientId,
      googleIosClientId: googleIosClientId,
      environment: environment,
    );
  }

  factory AppConfig.fromEnvironment() {
    final environment = _environmentFromBuild();
    final rawApiBaseUrl = const String.fromEnvironment('MM_API_BASE_URL');

    return AppConfig(
      apiBaseUrl: rawApiBaseUrl.isEmpty ? null : rawApiBaseUrl,
      googleServerClientId: const String.fromEnvironment(
        'MM_GOOGLE_SERVER_CLIENT_ID',
        defaultValue: '',
      ),
      googleIosClientId: const String.fromEnvironment(
        'MM_GOOGLE_IOS_CLIENT_ID',
        defaultValue: '',
      ),
      environment: environment,
    );
  }

  const AppConfig._({
    required this.apiBaseUrl,
    required this.googleServerClientId,
    required this.googleIosClientId,
    required this.environment,
  });

  static const String developmentApiBaseUrl = 'http://10.0.2.2:8080';

  final String apiBaseUrl;
  final String googleServerClientId;
  final String googleIosClientId;
  final AppEnvironment environment;

  static AppEnvironment _environmentFromBuild() {
    const rawEnvironment = String.fromEnvironment('MM_APP_ENVIRONMENT');
    if (rawEnvironment.isNotEmpty) {
      return switch (rawEnvironment) {
        'development' => AppEnvironment.development,
        'localPerformance' => AppEnvironment.localPerformance,
        'production' => AppEnvironment.production,
        _ => throw ArgumentError.value(
            rawEnvironment,
            'MM_APP_ENVIRONMENT',
            'must be development, localPerformance, or production',
          ),
      };
    }

    const isProductBuild = bool.fromEnvironment('dart.vm.product');
    return isProductBuild
        ? AppEnvironment.production
        : AppEnvironment.development;
  }

  static void _validateApiBaseUrl(
    String apiBaseUrl,
    AppEnvironment environment,
  ) {
    final trimmed = apiBaseUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('MM_API_BASE_URL must not be blank');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError('MM_API_BASE_URL must be an absolute API URL');
    }

    if (environment != AppEnvironment.production) {
      return;
    }

    if (uri.scheme != 'https') {
      throw ArgumentError('Production MM_API_BASE_URL must use https');
    }

    if (_isLocalDevelopmentHost(uri.host)) {
      throw ArgumentError(
        'Production MM_API_BASE_URL must not use a local development host',
      );
    }
  }

  static bool _isLocalDevelopmentHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == '10.0.2.2' ||
        normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }
}
