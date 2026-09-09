import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/invite/application/accept_invite_notifier.dart';
import 'package:memory_map/features/invite/application/accept_invite_state.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _acceptInviteBackground = Color(0xFFFBF6F1);
const _acceptInviteInk = Color(0xFF182331);
const _acceptInviteMuted = Color(0xFF747B86);
const _acceptInviteAccent = Color(0xFFD16A74);
const _acceptInviteAccentSoft = Color(0xFFFFEEF0);
const _acceptInviteWarmWhite = Color(0xFFFFFDFB);
const _acceptInviteWarmBorder = Color(0x1FD16A74);
const _acceptInviteDisplayFontFamily = 'NotoSerif';
const _acceptInviteTopDecorationAsset =
    'assets/transparent_accept_invite_open_envelope_polaroid_flowers.png';
const _acceptInviteBottomDecorationAsset =
    'assets/transparent_bottom-left_leaves.png';

class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({
    required String rawToken,
    this.onCancel,
    this.onAccepted,
    this.onUnavailable,
    super.key,
  }) : _rawToken = rawToken,
       _invalidLink = false;

  const AcceptInviteScreen.invalid({
    this.onCancel,
    super.key,
  }) : _rawToken = null,
       onAccepted = null,
       onUnavailable = null,
       _invalidLink = true;

  final String? _rawToken;
  final bool _invalidLink;
  final VoidCallback? onCancel;
  final ValueChanged<UserStory>? onAccepted;
  final VoidCallback? onUnavailable;

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inviteValue = ref.watch(acceptInviteProvider);
    final inviteState = inviteValue.asData?.value ?? const AcceptInviteState();
    final isAccepting = inviteState.isAccepting;
    final failureMessage = _failureMessage(l10n, inviteValue, inviteState);
    final canSubmit = !widget._invalidLink && !isAccepting;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isAccepting) {
          return;
        }

        widget.onCancel?.call();
      },
      child: Scaffold(
        backgroundColor: _acceptInviteBackground,
        body: Stack(
          children: [
            const Positioned(
              right: -44,
              top: -30,
              child: _AcceptInviteTopDecoration(),
            ),
            const Positioned(
              left: -34,
              bottom: -18,
              child: _AcceptInviteBottomDecoration(),
            ),
            SafeArea(
              bottom: false,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    sliver: SliverToBoxAdapter(
                      child: _AcceptInviteAppBar(
                        isAccepting: isAccepting,
                        onCancel: widget.onCancel,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 38, 24, 22),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AcceptInviteHeader(
                                invalid: widget._invalidLink,
                              ),
                              const SizedBox(height: 32),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoRow(
                                    icon: Icons.lock_outline_rounded,
                                    title: l10n.acceptInviteDetailsAccessTitle,
                                    body: l10n.acceptInviteDetailsAccessBody,
                                  ),
                                  const SizedBox(height: 20),
                                  _InfoRow(
                                    icon: Icons.verified_user_outlined,
                                    title: l10n
                                        .acceptInviteDetailsSingleUseTitle,
                                    body:
                                        l10n.acceptInviteDetailsSingleUseBody,
                                  ),
                                ],
                              ),
                              if (failureMessage != null) ...[
                                const SizedBox(height: 18),
                                _AcceptInviteFailureBanner(
                                  message: failureMessage,
                                ),
                              ],
                              const SizedBox(height: 26),
                              if (!widget._invalidLink)
                                Semantics(
                                  label: l10n.acceptInviteAcceptSemanticsLabel,
                                  button: true,
                                  enabled: canSubmit,
                                  child: FilledButton(
                                    key: const ValueKey(
                                      'accept-invite.accept-action',
                                    ),
                                    onPressed: canSubmit ? _acceptInvite : null,
                                    style: _primaryButtonStyle,
                                    child: isAccepting
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const SizedBox.square(
                                                dimension: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                l10n
                                                    .acceptInviteAcceptingAction,
                                              ),
                                            ],
                                          )
                                        : Text(
                                            failureMessage == null
                                                ? l10n
                                                    .acceptInviteAcceptAction
                                                : l10n.acceptInviteRetryAction,
                                          ),
                                  ),
                                ),
                              if (widget._invalidLink)
                                FilledButton(
                                  key: const ValueKey(
                                    'accept-invite.back-to-stories-action',
                                  ),
                                  onPressed: widget.onCancel,
                                  style: _primaryButtonStyle,
                                  child: Text(
                                    l10n.acceptInviteBackToStoriesAction,
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Semantics(
                                label: l10n.acceptInviteCancelSemanticsLabel,
                                button: true,
                                enabled: !isAccepting,
                                child: TextButton(
                                  key: const ValueKey(
                                    'accept-invite.cancel-action',
                                  ),
                                  onPressed:
                                      isAccepting ? null : widget.onCancel,
                                  style: _secondaryButtonStyle,
                                  child: Text(l10n.acceptInviteCancelAction),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _failureMessage(
    AppLocalizations l10n,
    AsyncValue<AcceptInviteState> inviteValue,
    AcceptInviteState inviteState,
  ) {
    if (widget._invalidLink) {
      return l10n.acceptInviteInvalidLinkDescription;
    }
    if (inviteValue.hasError) {
      return l10n.acceptInviteFailureUnknown;
    }

    final failure = inviteState.failure;
    if (failure == null) {
      return null;
    }

    return switch (failure) {
      InviteValidationFailure() => l10n.acceptInviteInvalidLinkDescription,
      InviteUnauthorized() => l10n.acceptInviteFailureUnauthorized,
      InviteNotFound() => l10n.acceptInviteUnavailable,
      InviteNetworkUnavailable() => l10n.inviteFailureNetworkUnavailable,
      InviteRequestTimedOut() => l10n.inviteFailureRequestTimedOut,
      InviteServerFailure() => l10n.inviteFailureServerFailure,
      UnknownInviteFailure() => l10n.acceptInviteFailureUnknown,
    };
  }

  Future<void> _acceptInvite() async {
    final token = widget._rawToken;
    if (token == null || _completed) {
      return;
    }

    final notifier = ref.read(acceptInviteProvider.notifier);
    if (ref.read(acceptInviteProvider).hasError) {
      notifier.reset();
    }

    final acceptedStory = await notifier.acceptInvite(token);
    final failure = ref.read(acceptInviteProvider).asData?.value.failure;
    if (failure is InviteValidationFailure || failure is InviteNotFound) {
      widget.onUnavailable?.call();
    }

    if (!mounted || acceptedStory == null || _completed) {
      return;
    }

    _completed = true;
    widget.onAccepted?.call(acceptedStory);
  }
}

class _AcceptInviteAppBar extends StatelessWidget {
  const _AcceptInviteAppBar({
    required this.isAccepting,
    required this.onCancel,
  });

  final bool isAccepting;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: IconButton(
        key: const ValueKey('accept-invite.back-action'),
        onPressed: isAccepting ? null : onCancel,
        tooltip: l10n.acceptInviteBackLabel,
        color: _acceptInviteInk,
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
    );
  }
}

class _AcceptInviteTopDecoration extends StatelessWidget {
  const _AcceptInviteTopDecoration();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Image.asset(
          _acceptInviteTopDecorationAsset,
          width: screenWidth.clamp(290, 390).toDouble(),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _AcceptInviteBottomDecoration extends StatelessWidget {
  const _AcceptInviteBottomDecoration();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Image.asset(
          _acceptInviteBottomDecorationAsset,
          width: (screenWidth * 0.54).clamp(170, 250).toDouble(),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _AcceptInviteHeader extends StatelessWidget {
  const _AcceptInviteHeader({
    required this.invalid,
  });

  final bool invalid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invalid
                ? l10n.acceptInviteInvalidLinkTitle
                : l10n.acceptInviteHeroTitle,
            style: const TextStyle(
              color: _acceptInviteInk,
              fontFamily: _acceptInviteDisplayFontFamily,
              fontFamilyFallback: <String>['NotoSerifGeorgian'],
              fontSize: 33,
              fontWeight: FontWeight.w500,
              height: 1.12,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            invalid
                ? l10n.acceptInviteInvalidLinkDescription
                : l10n.acceptInviteHeroDescription,
            style: const TextStyle(
              color: _acceptInviteMuted,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _acceptInviteAccentSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icon,
            color: _acceptInviteAccent,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _sectionTitleStyle),
              const SizedBox(height: 6),
              Text(body, style: _bodyTextStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _AcceptInviteFailureBanner extends StatelessWidget {
  const _AcceptInviteFailureBanner({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: AppLocalizations.of(context).acceptInviteErrorSemanticsLabel,
      child: Container(
        key: const ValueKey('accept-invite.failure-banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _acceptInviteWarmWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _acceptInviteWarmBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _acceptInviteAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _acceptInviteMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ButtonStyle get _primaryButtonStyle {
  return FilledButton.styleFrom(
    backgroundColor: _acceptInviteAccent,
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0x99D16A74),
    disabledForegroundColor: Colors.white,
    minimumSize: const Size.fromHeight(56),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
    textStyle: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    ),
  );
}

ButtonStyle get _secondaryButtonStyle {
  return TextButton.styleFrom(
    foregroundColor: _acceptInviteAccent,
    disabledForegroundColor: _acceptInviteMuted.withValues(alpha: 0.55),
    minimumSize: const Size.fromHeight(48),
    textStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
  );
}

const TextStyle _sectionTitleStyle = TextStyle(
  color: _acceptInviteInk,
  fontSize: 17,
  fontWeight: FontWeight.w800,
  letterSpacing: 0,
);

const TextStyle _bodyTextStyle = TextStyle(
  color: _acceptInviteMuted,
  fontSize: 15,
  height: 1.45,
  fontWeight: FontWeight.w500,
  letterSpacing: 0,
);
