import 'package:memory_map/features/invite/application/invite_application_exception.dart';
import 'package:memory_map/features/invite/data/remote/invite_remote_data_source.dart';
import 'package:memory_map/features/invite/data/remote/invite_remote_exception.dart';
import 'package:memory_map/features/invite/domain/accept_invite_input.dart';
import 'package:memory_map/features/invite/domain/create_invite_input.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/features/invite/domain/invite_repository.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

final class DefaultInviteRepository implements InviteRepository {
  const DefaultInviteRepository({
    required InviteRemoteDataSource inviteRemoteDataSource,
  }) : _inviteRemoteDataSource = inviteRemoteDataSource;

  final InviteRemoteDataSource _inviteRemoteDataSource;

  @override
  Future<Invite> createInvite(CreateInviteInput input) async {
    try {
      return await _inviteRemoteDataSource.createInvite(
        input.storyId,
        input.targetRole,
      );
    } on InviteRemoteException catch (exception) {
      throw InviteApplicationException(_mapFailure(exception));
    }
  }

  @override
  Future<UserStory> acceptInvite(AcceptInviteInput input) async {
    try {
      return await _inviteRemoteDataSource.acceptInvite(input.rawToken);
    } on InviteRemoteException catch (exception) {
      throw InviteApplicationException(_mapFailure(exception));
    }
  }

  InviteFailure _mapFailure(InviteRemoteException exception) {
    return switch (exception) {
      InviteRemoteValidationException() => const InviteValidationFailure(),
      InviteRemoteUnauthorizedException() => const InviteUnauthorized(),
      InviteRemoteNotFoundException() => const InviteNotFound(),
      InviteRemoteNetworkException() => const InviteNetworkUnavailable(),
      InviteRemoteTimeoutException() => const InviteRequestTimedOut(),
      InviteRemoteServerException() => const InviteServerFailure(),
      InviteRemoteMalformedResponseException() => const UnknownInviteFailure(),
      InviteRemoteUnknownException() => const UnknownInviteFailure(),
    };
  }
}
