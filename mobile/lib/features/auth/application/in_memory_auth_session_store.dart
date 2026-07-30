import 'dart:async';

import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_session_store.dart';

final class InMemoryAuthSessionStore implements AuthSessionStore {
  AuthSession? _session;
  bool _isDisposed = false;

  final StreamController<AuthSession?> _controller =
      StreamController<AuthSession?>.broadcast(sync: true);

  @override
  AuthSession? get session => _session;

  @override
  Stream<AuthSession?> get changes => _controller.stream;

  @override
  void setSession(AuthSession session) {
    if (_isDisposed) {
      return;
    }

    _session = session;
    _controller.add(session);
  }

  @override
  void clear() {
    if (_isDisposed) {
      return;
    }

    _session = null;
    _controller.add(null);
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _controller.close();
  }

  @override
  String toString() => 'InMemoryAuthSessionStore[REDACTED]';
}
