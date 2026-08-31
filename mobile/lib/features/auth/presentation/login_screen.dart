import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:memory_map/features/auth/application/auth_notifier.dart';
import 'package:memory_map/features/auth/application/auth_state.dart';
import 'package:memory_map/features/auth/presentation/auth_failure_message.dart';
import 'package:memory_map/features/auth/presentation/memory_map_brand_mark.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _heroAsset = 'assets/loginscreen.png';
const _googleLogoAsset = 'assets/google.svg';
const _screenBackground = Color(0xFFFBF7F4);
const _primaryText = Color(0xFF172330);
const _accent = Color(0xFFF55F6F);
const _secondaryText = Color(0xFF6F7883);
const _buttonBackground = Color(0xFF18232B);

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final l10n = AppLocalizations.of(context);
    final value = authState.asData?.value;
    final isAuthenticating = value is AuthAuthenticating;
    final failure = value is AuthLoginFailure
        ? authFailureMessage(l10n, value.failure)
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _screenBackground,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            final heroHeight = (constraints.maxHeight *
                    (isLandscape ? 0.62 : 0.53))
                .clamp(
                  isLandscape ? 260.0 : 380.0,
                  isLandscape ? 430.0 : 455.0,
                )
                .toDouble();

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    _LoginHero(height: heroHeight),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: _LoginContent(
                              l10n: l10n,
                              isAuthenticating: isAuthenticating,
                              failure: failure,
                              onPressed: isAuthenticating
                                  ? null
                                  : () {
                                      ref
                                          .read(authNotifierProvider.notifier)
                                          .loginWithGoogle();
                                    },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('login.hero.section'),
      height: height,
      width: double.infinity,
      child: ClipPath(
        clipper: const _HeroCurveClipper(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: Image.asset(
                _heroAsset,
                key: const ValueKey('login.hero.image'),
                fit: BoxFit.cover,
                alignment: const Alignment(0, 0.42),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _screenBackground.withValues(alpha: 0),
                      _screenBackground.withValues(alpha: 0.02),
                      _screenBackground.withValues(alpha: 0.16),
                      _screenBackground.withValues(alpha: 0.72),
                    ],
                    stops: const [0, 0.68, 0.86, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCurveClipper extends CustomClipper<Path> {
  const _HeroCurveClipper();

  @override
  Path getClip(Size size) {
    final curveInset = (size.height * 0.16).clamp(42.0, 64.0).toDouble();
    final controlDip = (size.height * 0.08).clamp(20.0, 30.0).toDouble();

    return Path()
      ..lineTo(0, size.height - curveInset)
      ..quadraticBezierTo(
        size.width / 2,
        size.height + controlDip,
        size.width,
        size.height - curveInset,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(_HeroCurveClipper oldClipper) => false;
}

class _LoginContent extends StatelessWidget {
  const _LoginContent({
    required this.l10n,
    required this.isAuthenticating,
    required this.failure,
    required this.onPressed,
  });

  final AppLocalizations l10n;
  final bool isAuthenticating;
  final String? failure;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final largeText = textScaler.scale(1) > 1.25;
    final logoSize = largeText ? 54.0 : 62.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: MemoryMapHeartPin(
            key: const ValueKey('login.memory-map.logo'),
            size: logoSize,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.appName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _primaryText,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.loginHeadline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _accent,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.28,
          ),
        ),
        const SizedBox(height: 10),
        const _HeartDivider(),
        const SizedBox(height: 12),
        Text(
          l10n.loginDescription,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _secondaryText,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            height: 1.42,
          ),
        ),
        const SizedBox(height: 20),
        _GoogleSignInButton(
          l10n: l10n,
          isAuthenticating: isAuthenticating,
          onPressed: onPressed,
        ),
        if (failure != null) ...[
          const SizedBox(height: 18),
          _FailureMessage(message: failure!),
        ],
        const SizedBox(height: 28),
        _LegalFooter(l10n: l10n),
      ],
    );
  }
}

class _HeartDivider extends StatelessWidget {
  const _HeartDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: _secondaryText.withValues(alpha: 0.22))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Icon(
            Icons.favorite,
            color: _accent,
            size: 24,
          ),
        ),
        Expanded(child: Divider(color: _secondaryText.withValues(alpha: 0.22))),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.l10n,
    required this.isAuthenticating,
    required this.onPressed,
  });

  final AppLocalizations l10n;
  final bool isAuthenticating;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('login.google.button.box'),
      height: 62,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _buttonBackground,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _buttonBackground.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          elevation: 10,
          shadowColor: _buttonBackground.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 24,
              child: Center(
                child: isAuthenticating
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                        ),
                      )
                    : SvgPicture.asset(
                        _googleLogoAsset,
                        width: 22,
                        height: 22,
                      ),
              ),
            ),
            const SizedBox(width: 18),
            Flexible(
              child: Text(
                isAuthenticating ? l10n.signingIn : l10n.continueWithGoogle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureMessage extends StatelessWidget {
  const _FailureMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFECEF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                color: _accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: _primaryText,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: _secondaryText,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.45,
    );
    const emphasisStyle = TextStyle(
      color: _accent,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.45,
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: '${l10n.loginLegalPrefix} '),
          TextSpan(text: l10n.privacyPolicy, style: emphasisStyle),
          TextSpan(text: ' ${l10n.legalSeparator} '),
          TextSpan(text: l10n.termsOfUse, style: emphasisStyle),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
