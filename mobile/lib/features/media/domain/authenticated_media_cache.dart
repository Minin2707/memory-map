import 'dart:typed_data';

abstract interface class AuthenticatedMediaCache {
  Future<Uint8List> getOrFetch(
    String backendPath,
    Future<Uint8List> Function() fetch,
  );

  Future<void> clear();
}

final class PassthroughAuthenticatedMediaCache
    implements AuthenticatedMediaCache {
  const PassthroughAuthenticatedMediaCache();

  @override
  Future<Uint8List> getOrFetch(
    String backendPath,
    Future<Uint8List> Function() fetch,
  ) {
    return fetch();
  }

  @override
  Future<void> clear() async {}
}
