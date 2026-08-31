import 'package:flutter/material.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const memoryMapWarmBackground = Color(0xFFFBF7F4);

const _brandText = Color(0xFF172330);
const _brandAccent = Color(0xFFF55F6F);

class MemoryMapBrandMark extends StatelessWidget {
  const MemoryMapBrandMark({
    super.key,
    this.pinKey,
    this.pinSize = 62,
    this.titleGap = 14,
  });

  final Key? pinKey;
  final double pinSize;
  final double titleGap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MemoryMapHeartPin(
          key: pinKey,
          size: pinSize,
        ),
        SizedBox(height: titleGap),
        Text(
          l10n.appName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _brandText,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class MemoryMapHeartPin extends StatelessWidget {
  const MemoryMapHeartPin({
    super.key,
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).appName,
      image: true,
      child: CustomPaint(
        size: Size(size, size * 1.16),
        painter: const _MemoryMapHeartPinPainter(),
      ),
    );
  }
}

class _MemoryMapHeartPinPainter extends CustomPainter {
  const _MemoryMapHeartPinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _brandAccent;
    final width = size.width;
    final height = size.height;
    final centerX = width / 2;
    final topY = height * 0.03;
    final widestY = height * 0.35;
    final lowerY = height * 0.74;
    final tipY = height;
    final widestHalf = width * 0.44;

    final pin = Path()
      ..moveTo(centerX, topY)
      ..cubicTo(
        centerX + width * 0.26,
        topY,
        centerX + widestHalf,
        height * 0.16,
        centerX + widestHalf,
        widestY,
      )
      ..cubicTo(
        centerX + widestHalf,
        height * 0.52,
        centerX + width * 0.27,
        lowerY,
        centerX,
        tipY,
      )
      ..cubicTo(
        centerX - width * 0.27,
        lowerY,
        centerX - widestHalf,
        height * 0.52,
        centerX - widestHalf,
        widestY,
      )
      ..cubicTo(
        centerX - widestHalf,
        height * 0.16,
        centerX - width * 0.26,
        topY,
        centerX,
        topY,
      )
      ..close();

    canvas.drawPath(pin, paint);

    final heartPaint = Paint()..color = Colors.white;
    final heartTopY = topY + width * 0.16;
    final heartMiddleY = topY + width * 0.34;
    final heartBottomY = topY + width * 0.52;
    final heart = Path()
      ..moveTo(centerX, heartBottomY)
      ..cubicTo(
        width * 0.24,
        heartMiddleY,
        width * 0.32,
        heartTopY,
        centerX,
        topY + width * 0.28,
      )
      ..cubicTo(
        width * 0.68,
        heartTopY,
        width * 0.76,
        heartMiddleY,
        centerX,
        heartBottomY,
      )
      ..close();

    canvas.drawPath(heart, heartPaint);
  }

  @override
  bool shouldRepaint(_MemoryMapHeartPinPainter oldDelegate) => false;
}
