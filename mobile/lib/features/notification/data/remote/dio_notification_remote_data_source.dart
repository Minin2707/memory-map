import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/data/network/authorized_dio_provider.dart';
import 'package:memory_map/features/notification/data/dto/notification_dto.dart';
import 'package:memory_map/features/notification/data/remote/notification_remote_data_source.dart';
import 'package:memory_map/features/notification/data/remote/notification_remote_exception.dart';
import 'package:memory_map/features/notification/domain/notification_item.dart';

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
  return DioNotificationRemoteDataSource(ref.watch(authorizedDioProvider));
});

final class DioNotificationRemoteDataSource
    implements NotificationRemoteDataSource {
  const DioNotificationRemoteDataSource(this._dio);

  static const String _notificationsPath = '/api/v1/notifications';

  final Dio _dio;

  @override
  Future<List<NotificationItem>> getNotifications({int limit = 50}) async {
    final response = await _get(
      _notificationsPath,
      queryParameters: <String, Object?>{'limit': limit},
    );

    _ensureExpectedStatus(response, 200);

    return _mapResponse(() {
      final data = response.data;
      if (data is! List) {
        throw const FormatException('Malformed notification response');
      }

      return data
          .map((item) => NotificationDto.fromJson(item).toDomain())
          .toList();
    });
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await _get('$_notificationsPath/unread-count');

    _ensureExpectedStatus(response, 200);

    return _mapResponse(() {
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('Malformed notification response');
      }

      final count = data.cast<Object?, Object?>()['count'];
      if (count is! int) {
        throw const FormatException('Malformed notification response');
      }

      return count;
    });
  }

  @override
  Future<void> markRead(String notificationId) async {
    final response = await _patch(_notificationReadPath(notificationId));

    _ensureExpectedStatus(response, 204);
  }

  @override
  Future<void> markAllRead() async {
    final response = await _patch('$_notificationsPath/read-all');

    _ensureExpectedStatus(response, 204);
  }

  Future<Response<Object?>> _get(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    try {
      return await _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      _throwMappedDioException(error);
    }
  }

  Future<Response<Object?>> _patch(String path) async {
    try {
      return await _dio.patch<Object?>(path);
    } on DioException catch (error) {
      _throwMappedDioException(error);
    }
  }

  String _notificationReadPath(String notificationId) {
    if (notificationId.trim().isEmpty) {
      throw ArgumentError('notificationId must not be blank');
    }

    return '$_notificationsPath/${Uri.encodeComponent(notificationId)}/read';
  }
}

T _mapResponse<T>(T Function() mapper) {
  try {
    return mapper();
  } on NotificationRemoteException {
    rethrow;
  } on Object {
    throw const NotificationRemoteMalformedResponseException();
  }
}

void _ensureExpectedStatus(
  Response<Object?> response,
  int expectedStatus,
) {
  if (response.statusCode == expectedStatus) {
    return;
  }

  _throwMappedStatus(response.statusCode);
}

Never _throwMappedDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      throw const NotificationRemoteTimeoutException();
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      throw const NotificationRemoteNetworkException();
    case DioExceptionType.badResponse:
      _throwMappedStatus(error.response?.statusCode);
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      throw const NotificationRemoteUnknownException();
  }
}

Never _throwMappedStatus(int? statusCode) {
  if (statusCode == 400) {
    throw const NotificationRemoteValidationException();
  }

  if (statusCode == 401 || statusCode == 403) {
    throw const NotificationRemoteUnauthorizedException();
  }

  if (statusCode == 404) {
    throw const NotificationRemoteNotFoundException();
  }

  if (statusCode != null && statusCode >= 500 && statusCode <= 599) {
    throw const NotificationRemoteServerException();
  }

  throw const NotificationRemoteUnknownException();
}
