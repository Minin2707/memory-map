package memory_map.backend.account.application;

import memory_map.backend.user.domain.User;

public interface CurrentUserAvatarUseCase {

    User uploadAvatar(UploadCurrentUserAvatarCommand command);

    DownloadedUserAvatar downloadAvatar(DownloadCurrentUserAvatarCommand command);

    User removeAvatar(RemoveCurrentUserAvatarCommand command);
}
