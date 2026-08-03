import 'package:flutter/foundation.dart';

@immutable
final class PendingInviteState {
  const PendingInviteState({this.rawToken});

  final String? rawToken;

  bool get hasInvite => rawToken != null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PendingInviteState && other.rawToken == rawToken;
  }

  @override
  int get hashCode => rawToken.hashCode;

  @override
  String toString() {
    return hasInvite ? 'PendingInviteState(hasInvite: true)' : 'PendingInviteState.empty';
  }
}
