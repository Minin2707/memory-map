final class RefreshTokenRequestDto {
  factory RefreshTokenRequestDto({
    required String refreshToken,
  }) {
    if (refreshToken.trim().isEmpty) {
      throw ArgumentError('refreshToken must not be blank');
    }

    return RefreshTokenRequestDto._(refreshToken);
  }

  const RefreshTokenRequestDto._(this.refreshToken);

  final String refreshToken;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'refreshToken': refreshToken,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RefreshTokenRequestDto &&
            refreshToken == other.refreshToken;
  }

  @override
  int get hashCode => refreshToken.hashCode;

  @override
  String toString() => 'RefreshTokenRequestDto[REDACTED]';
}
