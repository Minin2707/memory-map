import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/profile/application/default_account_repository.dart';
import 'package:memory_map/features/profile/data/remote/dio_account_remote_data_source.dart';
import 'package:memory_map/features/profile/domain/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => DefaultAccountRepository(ref.watch(accountRemoteDataSourceProvider)),
);
