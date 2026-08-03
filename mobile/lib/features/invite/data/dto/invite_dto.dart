import 'package:memory_map/features/invite/domain/invite.dart';

final class InviteDto {
  factory InviteDto.fromJson(Object? json) {
    final map = _inviteRequiredRootMap(json);

    return InviteDto(
      inviteLink: _inviteRequiredString(map, 'inviteLink'),
      expiresAt: _inviteRequiredDate(map, 'expiresAt'),
    );
  }

  InviteDto({
    required this.inviteLink,
    required this.expiresAt,
  }) {
    if (inviteLink.trim().isEmpty) {
      throw const FormatException('Malformed invite response');
    }
  }

  final String inviteLink;
  final DateTime expiresAt;

  Invite toDomain() {
    return Invite(
      inviteLink: Uri.parse(inviteLink),
      expiresAt: expiresAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InviteDto &&
            inviteLink == other.inviteLink &&
            expiresAt == other.expiresAt;
  }

  @override
  int get hashCode => Object.hash(
        inviteLink,
        expiresAt,
      );

  @override
  String toString() => 'InviteDto';
}

Map<Object?, Object?> _inviteRequiredRootMap(Object? json) {
  if (json is! Map) {
    throw const FormatException('Malformed invite response');
  }

  return json.cast<Object?, Object?>();
}

String _inviteRequiredString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed invite response');
  }

  return value;
}

DateTime _inviteRequiredDate(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed invite response');
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const FormatException('Malformed invite response');
  }

  return parsed;
}
