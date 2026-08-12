package memory_map.backend.media.storage;

import java.util.Objects;
import java.util.UUID;

public final class DeterministicMediaStorageKeyFactory
        implements MediaStorageKeyFactory {

    @Override
    public MediaStorageKeys keysFor(UUID mediaId) {
        Objects.requireNonNull(mediaId, "mediaId must not be null");

        return new MediaStorageKeys(
                new StorageKey("media/" + mediaId + "/display"),
                new StorageKey("media/" + mediaId + "/thumbnail")
        );
    }
}
