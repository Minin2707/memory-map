import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memory_map/features/invite/application/create_invite_notifier.dart';
import 'package:memory_map/features/invite/application/create_invite_state.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/presentation/invite_clipboard.dart';
import 'package:memory_map/features/invite/presentation/invite_failure_message.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/l10n/app_localizations.dart';

typedef InviteShareCallback = FutureOr<void> Function(String inviteLink);
typedef InviteDateFormatter = String Function(
  BuildContext context,
  DateTime value,
);

const _inviteBackground = Color(0xFFFBF6F1);
const _inviteInk = Color(0xFF182331);
const _inviteMuted = Color(0xFF747B86);
const _inviteAccent = Color(0xFFD16A74);
const _inviteAccentSoft = Color(0xFFFFEEF0);
const _inviteWarmWhite = Color(0xFFFFFDFB);
const _inviteWarmBorder = Color(0x1FD16A74);
const _inviteDisplayFontFamily = 'NotoSerif';
const _inviteTopDecorationAsset =
    'assets/transparent_invite_envelope_polaroid_flowers.png';
const _inviteBottomDecorationAsset =
    'assets/transparent_bottom-left_leaves.png';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({
    required this.storyId,
    required this.currentInviterRole,
    this.onBack,
    this.onShareInvite,
    this.clipboard = const FlutterInviteClipboard(),
    this.dateFormatter,
    super.key,
  });

  final String storyId;
  final StoryRole? currentInviterRole;
  final VoidCallback? onBack;
  final InviteShareCallback? onShareInvite;
  final InviteClipboard clipboard;
  final InviteDateFormatter? dateFormatter;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  StoryRole _selectedTargetRole = StoryRole.editor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inviteValue = ref.watch(createInviteProvider);
    final inviteState = inviteValue.asData?.value ?? const CreateInviteState();
    final invite = inviteState.createdInvite;
    final isCreating = inviteState.isCreating;
    final failureMessage = _failureMessage(l10n, inviteValue, inviteState);
    final dateFormatter = widget.dateFormatter ?? _formatInviteDate;
    final targetRoles = _targetRolesForInviterRole(widget.currentInviterRole);
    final canCreateInvite = targetRoles.contains(_selectedTargetRole);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isCreating) {
          return;
        }

        widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: _inviteBackground,
        body: Stack(
          children: [
            const Positioned(
              right: -42,
              top: -28,
              child: _InviteTopDecoration(),
            ),
            if (invite != null) const _InviteSuccessDecorationScrim(),
            const Positioned(
              left: -34,
              bottom: -18,
              child: _InviteBottomDecoration(),
            ),
            SafeArea(
              bottom: false,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    sliver: SliverToBoxAdapter(
                      child: _InviteAppBar(
                        isCreating: isCreating,
                        onBack: widget.onBack,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (invite == null)
                            _InviteInitialView(
                              targetRoles: targetRoles,
                              selectedTargetRole: _selectedTargetRole,
                              isCreating: isCreating,
                              failureMessage: failureMessage ??
                                  (targetRoles.isEmpty
                                      ? l10n.inviteFailureNotFound
                                      : null),
                              onTargetRoleChanged:
                                  isCreating ? null : _selectTargetRole,
                              onCreate: canCreateInvite ? _createInvite : null,
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
          ],
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

  void _selectTargetRole(StoryRole role) {
    if (!_targetRolesForInviterRole(widget.currentInviterRole)
        .contains(role)) {
      return;
    }

    setState(() {
      _selectedTargetRole = role;
    });
  }

  Future<void> _createInvite() {
    final notifier = ref.read(createInviteProvider.notifier);
    if (ref.read(createInviteProvider).hasError) {
      notifier.reset();
    }

    return notifier.createInvite(widget.storyId, _selectedTargetRole);
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

List<StoryRole> _targetRolesForInviterRole(StoryRole? inviterRole) {
  return switch (inviterRole) {
    StoryRole.owner => const [
        StoryRole.coOwner,
        StoryRole.editor,
        StoryRole.viewer,
      ],
    StoryRole.coOwner => const [
        StoryRole.editor,
        StoryRole.viewer,
      ],
    StoryRole.editor || StoryRole.viewer || null => const [],
  };
}

class _InviteAppBar extends StatelessWidget {
  const _InviteAppBar({
    required this.isCreating,
    required this.onBack,
  });

  final bool isCreating;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: IconButton(
        key: const ValueKey('invite.back-action'),
        onPressed: isCreating ? null : onBack,
        tooltip: l10n.inviteBackLabel,
        color: _inviteInk,
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
    );
  }
}

class _InviteTopDecoration extends StatelessWidget {
  const _InviteTopDecoration();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Image.asset(
          _inviteTopDecorationAsset,
          width: screenWidth.clamp(290, 390).toDouble(),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _InviteSuccessDecorationScrim extends StatelessWidget {
  const _InviteSuccessDecorationScrim();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.34, -0.48),
                radius: 1.05,
                colors: [
                  Color(0xF7FBF6F1),
                  Color(0xE8FBF6F1),
                  Color(0xA3FBF6F1),
                  Color(0x45FBF6F1),
                  Color(0x00FBF6F1),
                ],
                stops: [0, 0.32, 0.52, 0.72, 0.96],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteBottomDecoration extends StatelessWidget {
  const _InviteBottomDecoration();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Image.asset(
          _inviteBottomDecorationAsset,
          width: (screenWidth * 0.54).clamp(170, 250).toDouble(),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _InviteInitialView extends StatelessWidget {
  const _InviteInitialView({
    required this.targetRoles,
    required this.selectedTargetRole,
    required this.isCreating,
    required this.failureMessage,
    required this.onTargetRoleChanged,
    required this.onCreate,
  });

  final List<StoryRole> targetRoles;
  final StoryRole selectedTargetRole;
  final bool isCreating;
  final String? failureMessage;
  final ValueChanged<StoryRole>? onTargetRoleChanged;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InviteEditorialHeader(
          title: l10n.inviteHeroTitle,
          subtitle: l10n.inviteEditorialSubtitle,
        ),
        const SizedBox(height: 32),
        _InviteSectionTitle(l10n.inviteAboutSectionTitle),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              icon: Icons.link_rounded,
              title: l10n.inviteLinkLabel,
              body: l10n.inviteSingleUseDescription,
            ),
            const SizedBox(height: 18),
            _InfoRow(
              icon: Icons.event_available_rounded,
              title: l10n.inviteExpirationLabel,
              body: l10n.inviteExpirationDescription,
            ),
          ],
        ),
        if (targetRoles.isNotEmpty) ...[
          const SizedBox(height: 30),
          _InviteSectionTitle(l10n.inviteAccessSectionTitle),
          const SizedBox(height: 14),
          KeyedSubtree(
            key: const ValueKey('invite.role-selector-card'),
            child: _InviteRoleSelector(
              targetRoles: targetRoles,
              selectedTargetRole: selectedTargetRole,
              onChanged: onTargetRoleChanged,
            ),
          ),
        ],
        const SizedBox(height: 30),
        _InviteSectionTitle(l10n.inviteHowLinkWorksSectionTitle),
        const SizedBox(height: 14),
        _InstructionList(
          items: [
            l10n.inviteInstructionShare,
            l10n.inviteInstructionCopy,
            l10n.inviteInstructionOneUse,
          ],
        ),
        if (failureMessage != null) ...[
          const SizedBox(height: 18),
          _InviteFailureBanner(message: failureMessage!),
        ],
        const SizedBox(height: 26),
        FilledButton(
          key: const ValueKey('invite.create-action'),
          onPressed: isCreating ? null : onCreate,
          style: _primaryButtonStyle,
          child: isCreating
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    Text(l10n.inviteCreatingButton),
                  ],
                )
              : Text(
                  failureMessage == null
                      ? l10n.inviteCreateButton
                      : l10n.tryAgain,
                ),
        ),
      ],
    );
  }
}

class _InviteEditorialHeader extends StatelessWidget {
  const _InviteEditorialHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _inviteInk,
              fontFamily: _inviteDisplayFontFamily,
              fontFamilyFallback: <String>['NotoSerifGeorgian'],
              fontSize: 33,
              fontWeight: FontWeight.w500,
              height: 1.12,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              color: _inviteMuted,
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

class _InviteSectionTitle extends StatelessWidget {
  const _InviteSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: _sectionHeadingStyle,
    );
  }
}

class _InviteRoleSelector extends StatelessWidget {
  const _InviteRoleSelector({
    required this.targetRoles,
    required this.selectedTargetRole,
    required this.onChanged,
  });

  final List<StoryRole> targetRoles;
  final StoryRole selectedTargetRole;
  final ValueChanged<StoryRole>? onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<StoryRole>(
      groupValue: selectedTargetRole,
      onChanged: (role) {
        if (role != null) {
          onChanged?.call(role);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < targetRoles.length; index += 1) ...[
            if (index > 0) const SizedBox(height: 10),
            _InviteRoleOption(
              role: targetRoles[index],
              selected: targetRoles[index] == selectedTargetRole,
              onChanged: onChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _InviteRoleOption extends StatelessWidget {
  const _InviteRoleOption({
    required this.role,
    required this.selected,
    required this.onChanged,
  });

  final StoryRole role;
  final bool selected;
  final ValueChanged<StoryRole>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = onChanged != null;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('invite.role-option.${role.name}'),
        onTap: enabled ? () => onChanged!(role) : null,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected ? _inviteAccentSoft : _inviteWarmWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? const Color(0x66D16A74) : _inviteWarmBorder,
              width: selected ? 1.25 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Radio<StoryRole>(
                value: role,
                enabled: enabled,
                activeColor: _inviteAccent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_roleLabel(l10n, role), style: _sectionTitleStyle),
                    const SizedBox(height: 4),
                    Text(
                      _roleDescription(l10n, role),
                      style: _bodyTextStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _roleLabel(AppLocalizations l10n, StoryRole role) {
  return switch (role) {
    StoryRole.coOwner => l10n.inviteRoleCoOwnerLabel,
    StoryRole.editor => l10n.inviteRoleEditorLabel,
    StoryRole.viewer => l10n.inviteRoleViewerLabel,
    StoryRole.owner => l10n.storyRoleOwner,
  };
}

String _roleDescription(AppLocalizations l10n, StoryRole role) {
  return switch (role) {
    StoryRole.coOwner => l10n.inviteRoleCoOwnerDescription,
    StoryRole.editor => l10n.inviteRoleEditorDescription,
    StoryRole.viewer => l10n.inviteRoleViewerDescription,
    StoryRole.owner => l10n.storyRoleOwner,
  };
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
        _InviteSuccessHeader(
          pageTitle: l10n.inviteCreatedPageTitle,
          title: l10n.inviteSuccessTitle,
          subtitle: l10n.inviteSuccessSubtitle,
        ),
        const SizedBox(height: 24),
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
                      color: _inviteBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _inviteWarmBorder),
                    ),
                    child: SelectableText(
                      inviteLink,
                      key: const ValueKey('invite.link-text'),
                      style: const TextStyle(
                        color: _inviteInk,
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

class _InviteSuccessHeader extends StatelessWidget {
  const _InviteSuccessHeader({
    required this.pageTitle,
    required this.title,
    required this.subtitle,
  });

  final String pageTitle;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          pageTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _inviteMuted,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _inviteInk,
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
            color: _inviteMuted,
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
        color: _inviteWarmWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _inviteWarmBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0FD16A74),
            offset: Offset(0, 10),
            blurRadius: 22,
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
    this.title,
    required this.items,
  });

  final String? title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: _sectionTitleStyle),
          const SizedBox(height: 14),
        ],
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: _inviteAccent,
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
          color: _inviteWarmWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x52D16A74)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _inviteAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _inviteMuted,
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
            color: _inviteAccent,
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
        color: _inviteAccentSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        icon,
        color: _inviteAccent,
        size: 24,
      ),
    );
  }
}

ButtonStyle get _primaryButtonStyle {
  return FilledButton.styleFrom(
    backgroundColor: _inviteAccent,
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0xFFE8A7AE),
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
    foregroundColor: _inviteAccent,
    side: const BorderSide(color: Color(0x8FD16A74)),
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
  color: _inviteInk,
  fontSize: 17,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const TextStyle _bodyTextStyle = TextStyle(
  color: _inviteMuted,
  fontSize: 15,
  height: 1.45,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
);

const TextStyle _sectionHeadingStyle = TextStyle(
  color: Color(0xFF8A7770),
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w800,
  letterSpacing: 0,
);

String _formatInviteDate(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMd(locale).add_Hm().format(value.toLocal());
}
