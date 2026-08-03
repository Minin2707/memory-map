import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/invite/application/default_invite_repository.dart';
import 'package:memory_map/features/invite/data/remote/dio_invite_remote_data_source.dart';
import 'package:memory_map/features/invite/domain/invite_repository.dart';

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return DefaultInviteRepository(
    inviteRemoteDataSource: ref.watch(inviteRemoteDataSourceProvider),
  );
});
