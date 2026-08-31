import 'dart:ui';

import 'package:flutter/material.dart';

class GlassCircleIconButton extends StatelessWidget {
  const GlassCircleIconButton({
    Key? key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 52,
    this.foregroundColor = const Color(0xFF111827),
    this.disabledForegroundColor = const Color(0xFF8A93A3),
  })  : buttonKey = key,
        super(key: null);

  GlassCircleIconButton.icon({
    Key? key,
    required this.tooltip,
    required IconData icon,
    required this.onPressed,
    this.size = 52,
    this.foregroundColor = const Color(0xFF111827),
    this.disabledForegroundColor = const Color(0xFF8A93A3),
    double iconSize = 22,
  })  : buttonKey = key,
        icon = Icon(icon, size: iconSize),
        super(key: null);

  final Key? buttonKey;
  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final double size;
  final Color foregroundColor;
  final Color disabledForegroundColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: enabled ? 0.04 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: enabled ? 0.10 : 0.08),
                    Colors.white.withValues(alpha: enabled ? 0.04 : 0.03),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: enabled ? 0.14 : 0.10),
                  width: 0.5,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  key: buttonKey,
                  onPressed: onPressed,
                  tooltip: tooltip,
                  style: IconButton.styleFrom(
                    fixedSize: Size.square(size),
                    minimumSize: Size.square(size),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: foregroundColor,
                    disabledForegroundColor: disabledForegroundColor,
                    shape: const CircleBorder(),
                  ),
                  icon: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
