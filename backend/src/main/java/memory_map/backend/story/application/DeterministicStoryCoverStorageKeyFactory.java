package memory_map.backend.story.application;

import memory_map.backend.media.storage.StorageKey;

import java.util.Objects;
import java.util.UUID;

public final class DeterministicStoryCoverStorageKeyFactory
        implements StoryCoverStorageKeyFactory {

    @Override
    public StoryCoverStorageKeys keysFor(UUID storyId, UUID coverObjectId) {
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(
                coverObjectId,
                "coverObjectId must not be null"
        );

        return new StoryCoverStorageKeys(
                new StorageKey(
                        "stories/%s/cover/%s/display".formatted(
                                storyId,
                                coverObjectId
                        )
                ),
                new StorageKey(
                        "stories/%s/cover/%s/thumbnail".formatted(
                                storyId,
                                coverObjectId
                        )
                )
        );
    }
}
