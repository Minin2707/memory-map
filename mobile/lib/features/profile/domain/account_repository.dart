import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';

abstract interface class AccountRepository {
  Future<void> deleteCurrentAccount();

  Future<AuthUser> updateDisplayName(String displayName);

  Future<AuthUser> uploadCurrentUserAvatar(PreparedPhotoUpload photo);

  Future<AuthUser> removeCurrentUserAvatar();
}
