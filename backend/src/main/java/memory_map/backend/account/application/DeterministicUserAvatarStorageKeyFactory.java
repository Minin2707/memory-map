package memory_map.backend.account.application;

import memory_map.backend.media.storage.StorageKey;

import java.util.Objects;
import java.util.UUID;

public final class DeterministicUserAvatarStorageKeyFactory
        implements UserAvatarStorageKeyFactory {

    @Override
    public StorageKey keyFor(UUID userId, UUID avatarObjectId) {
        Objects.requireNonNull(userId, "userId must not be null");
        Objects.requireNonNull(
                avatarObjectId,
                "avatarObjectId must not be null"
        );

        return new StorageKey(
                "users/%s/avatar/%s".formatted(userId, avatarObjectId)
        );
    }
}
