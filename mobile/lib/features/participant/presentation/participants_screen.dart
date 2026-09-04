import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/participant/application/participants_notifier.dart';
import 'package:memory_map/features/participant/application/participants_state.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/presentation/participant_failure_message.dart';
import 'package:memory_map/features/participant/presentation/widgets/participant_tile.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/l10n/app_localizations.dart';

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
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ParticipantsState>>(
      storyParticipantsProvider(widget.storyId),
      _onParticipantsStateChanged,
    );

    final participantsValue = ref.watch(
      storyParticipantsProvider(widget.storyId),
    );
    final mutationActive = _hasParticipantMutation(participantsValue);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || mutationActive) {
          return;
        }

        widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFFFF5D72),
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
                    child: _ParticipantsAppBar(
                      onBack: mutationActive ? null : widget.onBack,
                    ),
                  ),
                ),
                ..._contentSlivers(context, ref, participantsValue),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
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
    final canInvite =
        widget.onInvite != null &&
        (currentRole == StoryRole.owner || currentRole == StoryRole.coOwner);
    final canLeave = widget.onLeftStory != null && currentParticipant != null;
    final mutationActive = state.isLeaving || state.isRemoving;

    return [
      if (state.isRefreshing)
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: LinearProgressIndicator(
              minHeight: 3,
              color: Color(0xFFFF5D72),
              backgroundColor: Color(0xFFFFE6EA),
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
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        sliver: SliverToBoxAdapter(
          child: _ParticipantsHeaderCard(
            participantCount: state.participants.length,
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
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        sliver: SliverToBoxAdapter(
          child: _SectionHeader(
            title: l10n.participantsSectionTitle,
            subtitle: l10n.participantsSectionSubtitle,
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
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
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
      if (canLeave)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
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
                backgroundColor: const Color(0xFFFF5D72),
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
                backgroundColor: const Color(0xFFFF5D72),
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

class _ParticipantsAppBar extends StatelessWidget {
  const _ParticipantsAppBar({
    required this.onBack,
  });

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        IconButton(
          key: const ValueKey('participants.back-action'),
          onPressed: onBack,
          tooltip: l10n.participantsBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            l10n.participantsPageTitle,
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

class _ParticipantsHeaderCard extends StatelessWidget {
  const _ParticipantsHeaderCard({
    required this.participantCount,
    required this.canInvite,
    required this.inviteEnabled,
    required this.onInvite,
  });

  final int participantCount;
  final bool canInvite;
  final bool inviteEnabled;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _ParticipantsCardShell(
      key: const ValueKey('participants.header-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE6EA),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.groups_2_rounded,
                  color: Color(0xFFFF5D72),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.participantsHeaderTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.participantsCount(participantCount),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canInvite && onInvite != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('participants.invite-action'),
              onPressed: inviteEnabled ? onInvite : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5D72),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(l10n.participantsInvite),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
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
    return _ParticipantsCardShell(
      key: const ValueKey('participants.list-card'),
      child: Column(
        children: [
          for (var index = 0; index < participants.length; index += 1) ...[
            if (index > 0) const Divider(height: 1, color: Color(0xFFE8EBEF)),
            ParticipantTile(
              participant: participants[index],
              isCurrentUser: participants[index].userId == currentUserId,
              showRemoveAction: _showRemoveAction(participants[index]),
              removeEnabled: removeEnabled,
              isRemoving:
                  removingParticipantUserId == participants[index].userId,
              onRemove: onRemovePressed,
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

    return _ParticipantsCardShell(
      key: const ValueKey('participants.leave-card'),
      child: OutlinedButton.icon(
        key: const ValueKey('participants.leave-action'),
        onPressed: isLeaving ? null : onLeavePressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF5D72),
          side: const BorderSide(color: Color(0xFFFF8A99)),
          minimumSize: const Size.fromHeight(56),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        icon: isLeaving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF5D72),
                ),
              )
            : const Icon(Icons.logout_rounded),
        label: Text(
          isLeaving ? l10n.participantsLeaving : l10n.participantsLeaveStory,
        ),
      ),
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
          color: const Color(0xFFFFF7F8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD6DC)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFFF5D72),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${l10n.participantsRefreshFailed}. $message',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
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
              color: const Color(0xFFFFE6EA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFFF5D72),
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
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
              color: const Color(0xFFFFE6EA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.group_off_rounded,
              color: Color(0xFFFF5D72),
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.participantsEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.participantsEmptyBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
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
        SizedBox(height: 20),
        _SkeletonBlock(height: 236),
        SizedBox(height: 20),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
        ],
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
