import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';

final class CreateInviteState {
  const CreateInviteState({
    this.isCreating = false,
    this.createdInvite,
    this.failure,
  });

  final bool isCreating;
  final Invite? createdInvite;
  final InviteFailure? failure;

  bool get hasCreatedInvite => createdInvite != null;

  CreateInviteState copyWith({
    bool? isCreating,
    Invite? createdInvite,
    InviteFailure? failure,
    bool clearCreatedInvite = false,
    bool clearFailure = false,
  }) {
    return CreateInviteState(
      isCreating: isCreating ?? this.isCreating,
      createdInvite:
          clearCreatedInvite ? null : createdInvite ?? this.createdInvite,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CreateInviteState &&
            isCreating == other.isCreating &&
            createdInvite == other.createdInvite &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        isCreating,
        createdInvite,
        failure,
      );

  @override
  String toString() {
    return 'CreateInviteState(isCreating: $isCreating, '
        'hasCreatedInvite: $hasCreatedInvite, failure: $failure)';
  }
}
