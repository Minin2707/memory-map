import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memory_map/features/invite/application/create_invite_notifier.dart';
import 'package:memory_map/features/invite/application/create_invite_state.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/presentation/invite_clipboard.dart';
import 'package:memory_map/features/invite/presentation/invite_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

typedef InviteShareCallback = FutureOr<void> Function(String inviteLink);
typedef InviteDateFormatter = String Function(
  BuildContext context,
  DateTime value,
);

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({
    required this.storyId,
    this.onBack,
    this.onShareInvite,
    this.clipboard = const FlutterInviteClipboard(),
    this.dateFormatter,
    super.key,
  });

  final String storyId;
  final VoidCallback? onBack;
  final InviteShareCallback? onShareInvite;
  final InviteClipboard clipboard;
  final InviteDateFormatter? dateFormatter;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inviteValue = ref.watch(createInviteProvider);
    final inviteState = inviteValue.asData?.value ?? const CreateInviteState();
    final invite = inviteState.createdInvite;
    final isCreating = inviteState.isCreating;
    final failureMessage = _failureMessage(l10n, inviteValue, inviteState);
    final dateFormatter = widget.dateFormatter ?? _formatInviteDate;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isCreating) {
          return;
        }

        widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                sliver: SliverToBoxAdapter(
                  child: _InviteAppBar(
                    title: invite == null
                        ? l10n.invitePageTitle
                        : l10n.inviteCreatedPageTitle,
                    isCreating: isCreating,
                    onBack: widget.onBack,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (invite == null)
                        _InviteInitialView(
                          isCreating: isCreating,
                          failureMessage: failureMessage,
                          onCreate: _createInvite,
                        )
                      else
                        _InviteSuccessView(
                          invite: invite,
                          expiresAtText: dateFormatter(
                            context,
                            invite.expiresAt,
                          ),
                          canShare: widget.onShareInvite != null,
                          onCopy: _copyInviteLink,
                          onShare: widget.onShareInvite == null
                              ? null
                              : _shareInviteLink,
                          onDone: isCreating ? null : widget.onBack,
                        ),
                    ],
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
    AsyncValue<CreateInviteState> inviteValue,
    CreateInviteState inviteState,
  ) {
    if (inviteValue.hasError) {
      return l10n.inviteFailureUnknown;
    }

    final failure = inviteState.failure;
    if (failure == null) {
      return null;
    }

    return inviteFailureMessage(l10n, failure);
  }

  Future<void> _createInvite() {
    final notifier = ref.read(createInviteProvider.notifier);
    if (ref.read(createInviteProvider).hasError) {
      notifier.reset();
    }

    return notifier.createInvite(widget.storyId);
  }

  Future<void> _copyInviteLink() async {
    final l10n = AppLocalizations.of(context);
    final invite = ref.read(createInviteProvider).asData?.value.createdInvite;
    if (invite == null) {
      return;
    }

    try {
      await widget.clipboard.writeText(invite.inviteLink.toString());
    } on Object {
      if (!mounted) {
        return;
      }

      _showSnackBar(l10n.inviteCopyFailure);
      return;
    }

    if (!mounted) {
      return;
    }

    _showSnackBar(l10n.inviteCopiedFeedback);
  }

  Future<void> _shareInviteLink() async {
    final l10n = AppLocalizations.of(context);
    final invite = ref.read(createInviteProvider).asData?.value.createdInvite;
    final share = widget.onShareInvite;
    if (invite == null || share == null) {
      return;
    }

    try {
      await share(invite.inviteLink.toString());
    } on Object {
      if (!mounted) {
        return;
      }

      _showSnackBar(l10n.inviteShareFailure);
      return;
    }

    if (!mounted) {
      return;
    }

    _showSnackBar(l10n.inviteShareReadyFeedback);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InviteAppBar extends StatelessWidget {
  const _InviteAppBar({
    required this.title,
    required this.isCreating,
    required this.onBack,
  });

  final String title;
  final bool isCreating;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        IconButton(
          key: const ValueKey('invite.back-action'),
          onPressed: isCreating ? null : onBack,
          tooltip: l10n.inviteBackLabel,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            title,
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

class _InviteInitialView extends StatelessWidget {
  const _InviteInitialView({
    required this.isCreating,
    required this.failureMessage,
    required this.onCreate,
  });

  final bool isCreating;
  final String? failureMessage;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InviteHero(
          icon: Icons.mail_rounded,
          title: l10n.inviteHeroTitle,
          subtitle: l10n.inviteHeroSubtitle,
        ),
        const SizedBox(height: 28),
        _InviteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                icon: Icons.link_rounded,
                title: l10n.inviteLinkLabel,
                body: l10n.inviteSingleUseDescription,
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFFE8EBEF)),
              const SizedBox(height: 18),
              _InfoRow(
                icon: Icons.event_available_rounded,
                title: l10n.inviteExpirationLabel,
                body: l10n.inviteExpirationDescription,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _InviteCard(
          child: _InstructionList(
            title: l10n.inviteWhatCanDoTitle,
            items: [
              l10n.inviteInstructionShare,
              l10n.inviteInstructionCopy,
              l10n.inviteInstructionOneUse,
            ],
          ),
        ),
        if (failureMessage != null) ...[
          const SizedBox(height: 16),
          _InviteFailureBanner(message: failureMessage!),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('invite.create-action'),
          onPressed: isCreating ? null : onCreate,
          style: _primaryButtonStyle,
          icon: isCreating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.link_rounded),
          label: Text(
            isCreating
                ? l10n.inviteCreatingButton
                : failureMessage == null
                    ? l10n.inviteCreateButton
                    : l10n.tryAgain,
          ),
        ),
      ],
    );
  }
}

class _InviteSuccessView extends StatelessWidget {
  const _InviteSuccessView({
    required this.invite,
    required this.expiresAtText,
    required this.canShare,
    required this.onCopy,
    required this.onShare,
    required this.onDone,
  });

  final Invite invite;
  final String expiresAtText;
  final bool canShare;
  final VoidCallback onCopy;
  final VoidCallback? onShare;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inviteLink = invite.inviteLink.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InviteHero(
          icon: Icons.check_rounded,
          title: l10n.inviteSuccessTitle,
          subtitle: l10n.inviteSuccessSubtitle,
          success: true,
        ),
        const SizedBox(height: 28),
        _InviteCard(
          key: const ValueKey('invite.result-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.inviteLinkLabel,
                style: _sectionTitleStyle,
              ),
              const SizedBox(height: 12),
              Semantics(
                label: l10n.inviteLinkSemanticsLabel,
                child: ExcludeSemantics(
                  child: Container(
                    key: const ValueKey('invite.link-container'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: SelectableText(
                      inviteLink,
                      key: const ValueKey('invite.link-text'),
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MetadataRow(
                icon: Icons.event_available_rounded,
                label: l10n.inviteExpirationLabel,
                value: expiresAtText,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('invite.copy-action'),
                      onPressed: onCopy,
                      style: _secondaryButtonStyle,
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(l10n.inviteCopyAction),
                    ),
                  ),
                  if (canShare) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('invite.share-action'),
                        onPressed: onShare,
                        style: _secondaryButtonStyle,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(l10n.inviteShareAction),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _InviteWarningCard(message: l10n.inviteLinkCannotBeRestoredWarning),
        const SizedBox(height: 18),
        _InviteCard(
          child: _InstructionList(
            title: l10n.inviteImportantTitle,
            items: [
              l10n.inviteImportantSingleUse,
              l10n.inviteImportantAfterAccept,
              l10n.inviteImportantExpiration,
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('invite.done-action'),
          onPressed: onDone,
          style: _primaryButtonStyle,
          child: Text(l10n.inviteDoneAction),
        ),
      ],
    );
  }
}

class _InviteHero extends StatelessWidget {
  const _InviteHero({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.success = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: success ? const Color(0xFFDFF8E7) : const Color(0xFFFFE6EA),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1FFF5D72),
                offset: Offset(0, 14),
                blurRadius: 28,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: success ? const Color(0xFF45C46A) : const Color(0xFFFF5D72),
            size: 46,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
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
          subtitle,
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

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.child,
    super.key,
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
        _IconBubble(icon: icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _sectionTitleStyle),
              const SizedBox(height: 6),
              Text(
                body,
                style: _bodyTextStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconBubble(icon: icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _sectionTitleStyle),
              const SizedBox(height: 4),
              Text(value, style: _bodyTextStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _InstructionList extends StatelessWidget {
  const _InstructionList({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _sectionTitleStyle),
        const SizedBox(height: 14),
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFFFF5D72),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item, style: _bodyTextStyle)),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _InviteFailureBanner extends StatelessWidget {
  const _InviteFailureBanner({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('invite.failure-banner'),
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

class _InviteWarningCard extends StatelessWidget {
  const _InviteWarningCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('invite.restore-warning'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F3),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFFF5D72),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
  });

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6EA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        icon,
        color: const Color(0xFFFF5D72),
        size: 24,
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

String _formatInviteDate(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMd(locale).add_Hm().format(value.toLocal());
}
