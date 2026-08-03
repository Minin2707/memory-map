import 'package:flutter/foundation.dart';

@immutable
final class InviteDeepLink {
  const InviteDeepLink(this.rawToken);

  final String rawToken;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InviteDeepLink && other.rawToken == rawToken;
  }

  @override
  int get hashCode => rawToken.hashCode;

  @override
  String toString() => 'InviteDeepLink';
}
