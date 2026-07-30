final class GoogleLoginRequestDto {
  factory GoogleLoginRequestDto({
    required String idToken,
  }) {
    if (idToken.trim().isEmpty) {
      throw ArgumentError('idToken must not be blank');
    }

    return GoogleLoginRequestDto._(idToken);
  }

  const GoogleLoginRequestDto._(this.idToken);

  final String idToken;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'idToken': idToken,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GoogleLoginRequestDto && idToken == other.idToken;
  }

  @override
  int get hashCode => idToken.hashCode;

  @override
  String toString() => 'GoogleLoginRequestDto[REDACTED]';
}
