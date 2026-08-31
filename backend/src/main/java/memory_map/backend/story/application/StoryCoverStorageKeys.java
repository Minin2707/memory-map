package memory_map.backend.story.application;

import memory_map.backend.media.storage.StorageKey;

import java.util.Objects;

public record StoryCoverStorageKeys(

        StorageKey display,

        StorageKey thumbnail

) {
    public StoryCoverStorageKeys {
        Objects.requireNonNull(display, "display must not be null");
        Objects.requireNonNull(thumbnail, "thumbnail must not be null");

        if (display.equals(thumbnail)) {
            throw new IllegalArgumentException(
                    "display and thumbnail must differ"
            );
        }
    }
}
