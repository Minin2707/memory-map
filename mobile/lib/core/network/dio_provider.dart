import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/core/config/app_config.dart';

final publicDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  ref.onDispose(dio.close);

  return dio;
});

final dioProvider = publicDioProvider;
