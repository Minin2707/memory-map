package memory_map.backend.account.application;

import memory_map.backend.media.storage.StorageKey;

import java.util.UUID;

public interface UserAvatarStorageKeyFactory {

    StorageKey keyFor(UUID userId, UUID avatarObjectId);
}
