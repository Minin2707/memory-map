import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/invite/application/accept_invite_notifier.dart';
import 'package:memory_map/features/invite/application/accept_invite_state.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/l10n/app_localizations.dart';

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
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AcceptInviteHero(
                            invalid: widget._invalidLink,
                          ),
                          const SizedBox(height: 28),
                          _AcceptInviteCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _InfoRow(
                                  icon: Icons.lock_outline_rounded,
                                  title: l10n.acceptInviteDetailsAccessTitle,
                                  body: l10n.acceptInviteDetailsAccessBody,
                                ),
                                const SizedBox(height: 18),
                                const Divider(color: Color(0xFFE8EBEF)),
                                const SizedBox(height: 18),
                                _InfoRow(
                                  icon: Icons.verified_user_outlined,
                                  title: l10n.acceptInviteDetailsSingleUseTitle,
                                  body: l10n.acceptInviteDetailsSingleUseBody,
                                ),
                              ],
                            ),
                          ),
                          if (failureMessage != null) ...[
                            const SizedBox(height: 16),
                            _AcceptInviteFailureBanner(message: failureMessage),
                          ],
                          const SizedBox(height: 24),
                          if (!widget._invalidLink)
                            Semantics(
                              label: l10n.acceptInviteAcceptSemanticsLabel,
                              button: true,
                              enabled: canSubmit,
                              child: FilledButton.icon(
                                key: const ValueKey('accept-invite.accept-action'),
                                onPressed: canSubmit ? _acceptInvite : null,
                                style: _primaryButtonStyle,
                                icon: isAccepting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_rounded),
                                label: Text(
                                  isAccepting
                                      ? l10n.acceptInviteAcceptingAction
                                      : failureMessage == null
                                      ? l10n.acceptInviteAcceptAction
                                      : l10n.acceptInviteRetryAction,
                                ),
                              ),
                            ),
                          if (widget._invalidLink) ...[
                            FilledButton.icon(
                              key: const ValueKey(
                                'accept-invite.back-to-stories-action',
                              ),
                              onPressed: widget.onCancel,
                              style: _primaryButtonStyle,
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: Text(l10n.acceptInviteBackToStoriesAction),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Semantics(
                            label: l10n.acceptInviteCancelSemanticsLabel,
                            button: true,
                            enabled: !isAccepting,
                            child: OutlinedButton.icon(
                              key: const ValueKey('accept-invite.cancel-action'),
                              onPressed: isAccepting ? null : widget.onCancel,
                              style: _secondaryButtonStyle,
                              icon: const Icon(Icons.close_rounded),
                              label: Text(l10n.acceptInviteCancelAction),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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

    return Row(
      children: [
        IconButton(
          key: const ValueKey('accept-invite.back-action'),
          onPressed: isAccepting ? null : onCancel,
          tooltip: l10n.acceptInviteBackLabel,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            l10n.acceptInvitePageTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _AcceptInviteHero extends StatelessWidget {
  const _AcceptInviteHero({
    required this.invalid,
  });

  final bool invalid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: invalid ? const Color(0xFFFFF1F3) : const Color(0xFFE7F1FF),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x121D4ED8),
                offset: Offset(0, 14),
                blurRadius: 28,
              ),
            ],
          ),
          child: Icon(
            invalid
                ? Icons.link_off_rounded
                : Icons.mark_email_read_outlined,
            color: invalid ? const Color(0xFFFF5D72) : const Color(0xFF2563EB),
            size: 46,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          invalid
              ? l10n.acceptInviteInvalidLinkTitle
              : l10n.acceptInviteHeroTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 32,
            fontWeight: FontWeight.w900,
            height: 1.12,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          invalid
              ? l10n.acceptInviteInvalidLinkDescription
              : l10n.acceptInviteHeroDescription,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 17,
            height: 1.45,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _AcceptInviteCard extends StatelessWidget {
  const _AcceptInviteCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            offset: Offset(0, 12),
            blurRadius: 28,
          ),
        ],
      ),
      child: child,
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
            color: const Color(0xFFE7F1FF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF2563EB),
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
          color: const Color(0xFFFFF7F8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD6DC)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFFF5D72),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
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
    backgroundColor: const Color(0xFFFF5D72),
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0xFFFFB3BD),
    disabledForegroundColor: Colors.white,
    minimumSize: const Size.fromHeight(58),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
    textStyle: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
    ),
  );
}

ButtonStyle get _secondaryButtonStyle {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFFFF5D72),
    side: const BorderSide(color: Color(0xFFFF8A99)),
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
    textStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    ),
  );
}

const TextStyle _sectionTitleStyle = TextStyle(
  color: Color(0xFF1F2937),
  fontSize: 17,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const TextStyle _bodyTextStyle = TextStyle(
  color: Color(0xFF6B7280),
  fontSize: 15,
  height: 1.45,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
);
