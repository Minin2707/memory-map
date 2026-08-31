import 'package:flutter/material.dart';
import 'package:memory_map/features/auth/presentation/memory_map_brand_mark.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const startupBrandingAnimationDuration = Duration(milliseconds: 1100);
const _startupPinFadeStart = 100 / 1100;
const _startupPinFadeEnd = 380 / 1100;
const _startupTitleRevealStart = 420 / 1100;
const _startupTitleRevealEnd = 950 / 1100;

class AuthCheckingScreen extends StatefulWidget {
  const AuthCheckingScreen({
    this.onBrandAnimationCompleted,
    super.key,
  });

  final VoidCallback? onBrandAnimationCompleted;

  @override
  State<AuthCheckingScreen> createState() => _AuthCheckingScreenState();
}

class _AuthCheckingScreenState extends State<AuthCheckingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationStartScheduled = false;
  bool _animationStarted = false;
  bool _completionNotified = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: startupBrandingAnimationDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _notifyAnimationCompleted();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _animationStartScheduled = true;
      _animationStarted = true;
      _controller.value = 1;
      _notifyAnimationCompleted();
      return;
    }

    if (!_animationStartScheduled) {
      _animationStartScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _animationStarted || _completionNotified) {
          return;
        }

        _animationStarted = true;
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _notifyAnimationCompleted() {
    if (_completionNotified) {
      return;
    }

    _completionNotified = true;
    final onBrandAnimationCompleted = widget.onBrandAnimationCompleted;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      onBrandAnimationCompleted?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: memoryMapWarmBackground,
      body: SafeArea(
        child: Center(
          child: _AnimatedStartupBrandMark(
            controller: _controller,
          ),
        ),
      ),
    );
  }
}

class _AnimatedStartupBrandMark extends StatelessWidget {
  const _AnimatedStartupBrandMark({
    required this.controller,
  });

  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    final appName = AppLocalizations.of(context).appName;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pinProgress = _intervalProgress(
          controller.value,
          start: _startupPinFadeStart,
          end: _startupPinFadeEnd,
        );
        final textProgress = _intervalProgress(
          controller.value,
          start: _startupTitleRevealStart,
          end: _startupTitleRevealEnd,
        );
        final visibleLength =
            (Curves.easeOutCubic.transform(textProgress) * appName.length)
                .ceil()
                .clamp(0, appName.length)
                .toInt();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: Curves.easeOut.transform(pinProgress),
              child: Transform.scale(
                scale: 0.92 + (0.08 * Curves.easeOutCubic.transform(
                  pinProgress,
                )),
                child: const MemoryMapHeartPin(
                  key: ValueKey('auth-checking.memory-map.logo'),
                  size: 62,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              label: appName,
              child: ExcludeSemantics(
                child: Text(
                  appName.substring(0, visibleLength),
                  key: const ValueKey('auth-checking.memory-map.title'),
                  textAlign: TextAlign.center,
                  style: memoryMapBrandTitleStyle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _intervalProgress(
    double value, {
    required double start,
    required double end,
  }) {
    return ((value - start) / (end - start)).clamp(0.0, 1.0);
  }
}
