package memory_map.backend.media.storage;

import java.util.Objects;

public record MediaStorageKeys(

        StorageKey display,

        StorageKey thumbnail

) {
    public MediaStorageKeys {
        Objects.requireNonNull(display, "display must not be null");
        Objects.requireNonNull(thumbnail, "thumbnail must not be null");

        if (display.equals(thumbnail)) {
            throw new IllegalArgumentException(
                    "display and thumbnail storage keys must differ"
            );
        }
    }

    @Override
    public String toString() {
        return "MediaStorageKeys[hasDisplay=true, hasThumbnail=true]";
    }
}
