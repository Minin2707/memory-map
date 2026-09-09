import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/participant/application/participants_notifier.dart';
import 'package:memory_map/features/participant/application/participants_state.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/presentation/participant_failure_message.dart';
import 'package:memory_map/features/participant/presentation/widgets/participant_tile.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _participantsBackground = Color(0xFFFBF6F1);
const _participantsInk = Color(0xFF182331);
const _participantsMuted = Color(0xFF747B86);
const _participantsAccent = Color(0xFFD16A74);
const _participantsAccentSoft = Color(0xFFFFEEF0);
const _participantsAccentDisabled = Color(0x6BD16A74);
const _participantsWarmWhite = Color(0xFFFFFDFB);
const _participantsWarmBorder = Color(0x1FD16A74);
const _participantsDisplayFontFamily = 'NotoSerif';
const _participantsDisplayFontFallback = <String>['NotoSerifGeorgian'];
const _participantsTopDecorationAsset =
    'assets/participants_header_polaroids_flowers.png';
const _participantsBottomDecorationAsset =
    'assets/transparent_bottom-left_leaves.png';

class ParticipantsScreen extends ConsumerStatefulWidget {
  const ParticipantsScreen({
    required this.storyId,
    required this.currentUserId,
    this.onBack,
    this.onInvite,
    this.onLeftStory,
    this.onParticipantRemoved,
    super.key,
  });

  final String storyId;
  final String currentUserId;
  final VoidCallback? onBack;
  final ValueChanged<StoryRole>? onInvite;
  final VoidCallback? onLeftStory;
  final ValueChanged<StoryParticipant>? onParticipantRemoved;

  @override
  ConsumerState<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends ConsumerState<ParticipantsScreen> {
  @override
  void initState() {
    super.initState();
    _refreshParticipantsOnEntry();
  }

  @override
  void didUpdateWidget(ParticipantsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storyId != widget.storyId) {
      _refreshParticipantsOnEntry();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ParticipantsState>>(
      storyParticipantsProvider(widget.storyId),
      _onParticipantsStateChanged,
    );

    final participantsValue = ref.watch(
      storyParticipantsProvider(widget.storyId),
    );
    final mutationActive = _hasParticipantMutation(participantsValue);
    final loadedState = participantsValue.asData?.value;
    final loadedParticipants = loadedState != null && loadedState.isLoaded
        ? loadedState.participants
        : null;
    final participantCount = loadedParticipants?.length;
    final currentRole = loadedParticipants == null
        ? null
        : _currentParticipant(loadedParticipants)?.role;
    final canInvite =
        widget.onInvite != null &&
        (currentRole == StoryRole.owner || currentRole == StoryRole.coOwner);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || mutationActive) {
          return;
        }

        widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: _participantsBackground,
        body: Stack(
          children: [
            const Positioned(
              right: -22,
              top: -18,
              child: _ParticipantsTopDecoration(),
            ),
            const Positioned(
              left: -24,
              bottom: -10,
              child: _ParticipantsBottomDecoration(),
            ),
            SafeArea(
              child: RefreshIndicator(
                color: _participantsAccent,
                onRefresh: () {
                  return ref
                      .read(storyParticipantsProvider(widget.storyId).notifier)
                      .refreshParticipants();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      sliver: SliverToBoxAdapter(
                        child: _ParticipantsHeader(
                          onBack: mutationActive ? null : widget.onBack,
                          participantCount: participantCount,
                          canInvite: canInvite,
                          inviteEnabled: !mutationActive,
                          onInvite: canInvite
                              ? () {
                                  widget.onInvite!(currentRole!);
                                }
                              : null,
                        ),
                      ),
                    ),
                    ..._contentSlivers(context, ref, participantsValue),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ParticipantsState> participantsValue,
  ) {
    final l10n = AppLocalizations.of(context);

    if (participantsValue.isLoading) {
      return const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverToBoxAdapter(child: _ParticipantsLoadingView()),
        ),
      ];
    }

    if (participantsValue.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Center(
              child: _ParticipantsErrorView(
                title: l10n.unexpectedErrorTitle,
                message: l10n.participantFailureUnknown,
                onRetry: () {
                  ref
                      .read(storyParticipantsProvider(widget.storyId).notifier)
                      .retryLoad();
                },
              ),
            ),
          ),
        ),
      ];
    }

    final state = participantsValue.asData?.value;
    if (state == null) {
      return const [];
    }

    final loadFailure = state.loadFailure;
    if (loadFailure != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Center(
              child: _ParticipantsErrorView(
                title: l10n.participantsLoadFailed,
                message: participantFailureMessage(l10n, loadFailure),
                onRetry: () {
                  ref
                      .read(storyParticipantsProvider(widget.storyId).notifier)
                      .retryLoad();
                },
              ),
            ),
          ),
        ),
      ];
    }

    final currentParticipant = _currentParticipant(state.participants);
    final currentRole = currentParticipant?.role;
    final canLeave = widget.onLeftStory != null && currentParticipant != null;
    final mutationActive = state.isLeaving || state.isRemoving;

    return [
      if (state.isRefreshing)
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: LinearProgressIndicator(
              minHeight: 3,
              color: _participantsAccent,
              backgroundColor: _participantsAccentSoft,
            ),
          ),
        ),
      if (state.refreshFailure != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _RefreshFailureBanner(
              message: participantFailureMessage(
                l10n,
                state.refreshFailure!,
              ),
              onRetry: () {
                ref
                    .read(storyParticipantsProvider(widget.storyId).notifier)
                    .refreshParticipants();
              },
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
        sliver: SliverToBoxAdapter(
          child: _SectionHeader(
            title: l10n.participantsHeaderTitle,
          ),
        ),
      ),
      if (state.participants.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Center(child: _ParticipantsEmptyState()),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _ParticipantsCard(
              participants: state.participants,
              currentUserId: currentUserId,
              currentRole: currentRole,
              removeEnabled: !state.hasActiveOperation,
              removingParticipantUserId: state.removingParticipantUserId,
              onRemovePressed: widget.onParticipantRemoved == null
                  ? null
                  : _confirmRemoveParticipant,
            ),
          ),
        ),
      if (state.participants.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _RoleExplanation(text: l10n.participantsSectionSubtitle),
          ),
        ),
      if (canLeave)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _LeaveStoryCard(
              isLeaving: state.isLeaving,
              onLeavePressed: mutationActive ? null : _confirmLeaveStory,
            ),
          ),
        ),
    ];
  }

  StoryParticipant? _currentParticipant(List<StoryParticipant> participants) {
    for (final participant in participants) {
      if (participant.userId == currentUserId) {
        return participant;
      }
    }

    return null;
  }

  String get storyId => widget.storyId;

  String get currentUserId => widget.currentUserId;

  bool _hasParticipantMutation(AsyncValue<ParticipantsState> value) {
    final state = value.asData?.value;
    return (state?.isLeaving ?? false) || (state?.isRemoving ?? false);
  }

  bool _operationActive() {
    final state = ref.read(storyParticipantsProvider(storyId)).asData?.value;
    return state?.hasActiveOperation ?? false;
  }

  void _refreshParticipantsOnEntry() {
    final storyId = widget.storyId;
    final provider = storyParticipantsProvider(storyId);
    if (!ref.exists(provider)) {
      return;
    }

    final state = ref.read(provider).asData?.value;
    if (state == null || !state.isLoaded || state.hasActiveOperation) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.storyId != storyId) {
        return;
      }

      ref.read(provider.notifier).refreshParticipants();
    });
  }

  void _onParticipantsStateChanged(
    AsyncValue<ParticipantsState>? previous,
    AsyncValue<ParticipantsState> next,
  ) {
    final previousState = previous?.asData?.value;
    final nextState = next.asData?.value;
    if (nextState == null) {
      return;
    }

    final leaveFailure = nextState.leaveFailure;
    if (leaveFailure != null && previousState?.leaveFailure != leaveFailure) {
      _showSnackBar(participantFailureMessage(
        AppLocalizations.of(context),
        leaveFailure,
      ));
    }

    final removeFailure = nextState.removeFailure;
    if (removeFailure != null &&
        previousState?.removeFailure != removeFailure) {
      _showSnackBar(participantFailureMessage(
        AppLocalizations.of(context),
        removeFailure,
      ));
    }
  }

  Future<void> _confirmLeaveStory() async {
    if (_operationActive()) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);

        return AlertDialog(
          title: Text(l10n.participantsLeaveConfirmTitle),
          content: Text(l10n.participantsLeaveConfirmBody),
          actions: [
            TextButton(
              key: const ValueKey('participants.leave.cancel-action'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(l10n.participantsLeaveCancel),
            ),
            FilledButton(
              key: const ValueKey('participants.leave.confirm-action'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _participantsAccent,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.participantsLeaveConfirmAction),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || _operationActive()) {
      return;
    }

    final success = await ref
        .read(storyParticipantsProvider(storyId).notifier)
        .leaveStory();

    if (!mounted || !success) {
      return;
    }

    widget.onLeftStory?.call();
  }

  Future<void> _confirmRemoveParticipant(StoryParticipant participant) async {
    if (_operationActive()) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);

        return AlertDialog(
          title: Text(
            l10n.participantsRemoveConfirmTitle(participant.displayName),
          ),
          content: Text(
            l10n.participantsRemoveConfirmBody(participant.displayName),
          ),
          actions: [
            TextButton(
              key: const ValueKey('participants.remove.cancel-action'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(l10n.participantsRemoveCancel),
            ),
            FilledButton(
              key: const ValueKey('participants.remove.confirm-action'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _participantsAccent,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.participantsRemoveConfirmAction),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || _operationActive()) {
      return;
    }

    final success = await ref
        .read(storyParticipantsProvider(storyId).notifier)
        .removeParticipant(participant.userId);

    if (!mounted || !success) {
      return;
    }

    _showSnackBar(
      AppLocalizations.of(context)
          .participantsRemoveSuccess(participant.displayName),
    );
    widget.onParticipantRemoved?.call(participant);
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ParticipantsHeader extends StatelessWidget {
  const _ParticipantsHeader({
    required this.onBack,
    required this.participantCount,
    required this.canInvite,
    required this.inviteEnabled,
    required this.onInvite,
  });

  final VoidCallback? onBack;
  final int? participantCount;
  final bool canInvite;
  final bool inviteEnabled;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return KeyedSubtree(
      key: const ValueKey('participants.header-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            key: const ValueKey('participants.back-action'),
            onPressed: onBack,
            tooltip: l10n.participantsBack,
            color: _participantsInk,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.participantsPageTitle,
                  style: const TextStyle(
                    color: _participantsInk,
                    fontFamily: _participantsDisplayFontFamily,
                    fontFamilyFallback: _participantsDisplayFontFallback,
                    fontSize: 34,
                    height: 1.08,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
                if (participantCount != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.participantsCount(participantCount!),
                    style: const TextStyle(
                      color: _participantsMuted,
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canInvite && onInvite != null) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _ParticipantsInviteActionRow(
                enabled: inviteEnabled,
                onPressed: onInvite,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParticipantsTopDecoration extends StatelessWidget {
  const _ParticipantsTopDecoration();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Image.asset(
          _participantsTopDecorationAsset,
          width: (screenWidth * 0.52).clamp(170, 210).toDouble(),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _ParticipantsBottomDecoration extends StatelessWidget {
  const _ParticipantsBottomDecoration();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Image.asset(
          _participantsBottomDecorationAsset,
          width: (screenWidth * 0.4).clamp(145, 155).toDouble(),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _ParticipantsInviteActionRow extends StatelessWidget {
  const _ParticipantsInviteActionRow({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TextButton(
      key: const ValueKey('participants.invite-action'),
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        backgroundColor: _participantsWarmWhite,
        disabledBackgroundColor: _participantsWarmWhite,
        foregroundColor: _participantsInk,
        disabledForegroundColor: _participantsMuted,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _participantsWarmBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _participantsAccentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.add_rounded,
                color: enabled
                    ? _participantsAccent
                    : _participantsAccentDisabled,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.participantsInvite,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.chevron_right_rounded,
              color: enabled ? _participantsAccent : _participantsMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _participantsMuted,
        fontSize: 13,
        height: 1.25,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _ParticipantsCard extends StatelessWidget {
  const _ParticipantsCard({
    required this.participants,
    required this.currentUserId,
    required this.currentRole,
    required this.removeEnabled,
    required this.removingParticipantUserId,
    required this.onRemovePressed,
  });

  final List<StoryParticipant> participants;
  final String currentUserId;
  final StoryRole? currentRole;
  final bool removeEnabled;
  final String? removingParticipantUserId;
  final ValueChanged<StoryParticipant>? onRemovePressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('participants.list-card'),
      width: double.infinity,
      child: Column(
        children: [
          for (var index = 0; index < participants.length; index += 1) ...[
            if (index > 0) const SizedBox(height: 12),
            _ParticipantRowSurface(
              child: ParticipantTile(
                participant: participants[index],
                isCurrentUser: participants[index].userId == currentUserId,
                showRemoveAction: _showRemoveAction(participants[index]),
                removeEnabled: removeEnabled,
                isRemoving:
                    removingParticipantUserId == participants[index].userId,
                onRemove: onRemovePressed,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _showRemoveAction(StoryParticipant target) {
    return currentRole == StoryRole.owner &&
        target.userId != currentUserId &&
        target.role != StoryRole.owner &&
        onRemovePressed != null;
  }
}

class _ParticipantRowSurface extends StatelessWidget {
  const _ParticipantRowSurface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _participantsWarmWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _participantsWarmBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: child,
      ),
    );
  }
}

class _LeaveStoryCard extends StatelessWidget {
  const _LeaveStoryCard({
    required this.isLeaving,
    required this.onLeavePressed,
  });

  final bool isLeaving;
  final VoidCallback? onLeavePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      key: const ValueKey('participants.leave-card'),
      children: [
        Center(
          child: TextButton.icon(
            key: const ValueKey('participants.leave-action'),
            onPressed: isLeaving ? null : onLeavePressed,
            style: TextButton.styleFrom(
              foregroundColor: _participantsAccent,
              disabledForegroundColor: const Color(0x85D16A74),
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            icon: isLeaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _participantsAccent,
                    ),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(
              isLeaving
                  ? l10n.participantsLeaving
                  : l10n.participantsLeaveStory,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleExplanation extends StatelessWidget {
  const _RoleExplanation({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: _participantsMuted,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _participantsMuted,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _RefreshFailureBanner extends StatelessWidget {
  const _RefreshFailureBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('participants.refresh.failure-banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _participantsAccentSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _participantsWarmBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _participantsAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${l10n.participantsRefreshFailed}. $message',
                style: const TextStyle(
                  color: _participantsMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('participants.refresh.retry-action'),
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantsErrorView extends StatelessWidget {
  const _ParticipantsErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _ParticipantsCardShell(
      key: const ValueKey('participants.error-view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _participantsAccentSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: _participantsAccent,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _participantsInk,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _participantsMuted,
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            key: const ValueKey('participants.error.retry-action'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

class _ParticipantsEmptyState extends StatelessWidget {
  const _ParticipantsEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _ParticipantsCardShell(
      key: const ValueKey('participants.empty-state'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _participantsAccentSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.group_off_rounded,
              color: _participantsAccent,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.participantsEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _participantsInk,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.participantsEmptyBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _participantsMuted,
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantsLoadingView extends StatelessWidget {
  const _ParticipantsLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('participants.loading-view'),
      children: const [
        _SkeletonBlock(height: 138),
        SizedBox(height: 16),
        _SkeletonBlock(height: 236),
        SizedBox(height: 16),
        _SkeletonBlock(height: 86),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.height,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: _participantsWarmWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _participantsWarmBorder),
      ),
    );
  }
}

class _ParticipantsCardShell extends StatelessWidget {
  const _ParticipantsCardShell({
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
        color: _participantsWarmWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _participantsWarmBorder),
      ),
      child: child,
    );
  }
}
