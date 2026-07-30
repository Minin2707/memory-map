import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((_) {
  return const AppConfig();
});

final class AppConfig {
  const AppConfig({
    this.apiBaseUrl = const String.fromEnvironment(
      'MM_API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080',
    ),
  });

  final String apiBaseUrl;
}
