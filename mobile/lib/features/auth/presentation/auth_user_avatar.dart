import 'package:flutter/material.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';

class AuthUserAvatar extends StatelessWidget {
  const AuthUserAvatar({
    required this.displayName,
    required this.avatarUrl,
    required this.radius,
    this.backgroundColor = Colors.white,
    this.foregroundColor = const Color(0xFFFF5D72),
    this.cacheDimension,
    super.key,
  });

  final String displayName;
  final String? avatarUrl;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final int? cacheDimension;

  @override
  Widget build(BuildContext context) {
    final effectiveAvatarUrl = avatarUrl?.trim();
    final fallback = _AvatarFallback(
      displayName: displayName,
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );

    if (effectiveAvatarUrl == null || effectiveAvatarUrl.isEmpty) {
      return fallback;
    }

    final uri = Uri.tryParse(effectiveAvatarUrl);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      return CircleAvatar(
        radius: radius,
        foregroundImage: NetworkImage(effectiveAvatarUrl),
        onForegroundImageError: (_, __) {},
        backgroundColor: backgroundColor,
        child: _Initial(
          displayName: displayName,
          fontSize: radius * 0.66,
          color: foregroundColor,
        ),
      );
    }

    return ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: AuthenticatedMediaPathImage(
          thumbnailPath: effectiveAvatarUrl,
          representation: AuthenticatedMediaRepresentation.display,
          fit: BoxFit.cover,
          cacheWidth: cacheDimension,
          cacheHeight: cacheDimension,
          placeholder: _AvatarFallback(
            displayName: displayName,
            radius: radius,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
          ),
          errorBuilder: (_) => _AvatarFallback(
            displayName: displayName,
            radius: radius,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
          ),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.displayName,
    required this.radius,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String displayName;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: _Initial(
        displayName: displayName,
        fontSize: radius * 0.66,
        color: foregroundColor,
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({
    required this.displayName,
    required this.fontSize,
    required this.color,
  });

  final String displayName;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      _initial(displayName),
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '?';
    }

    return trimmed.substring(0, 1).toUpperCase();
  }
}
