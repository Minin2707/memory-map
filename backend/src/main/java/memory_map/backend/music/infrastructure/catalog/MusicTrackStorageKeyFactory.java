package memory_map.backend.music.infrastructure.catalog;

import java.util.Objects;
import java.util.UUID;

public final class MusicTrackStorageKeyFactory {

    public String storageKeyFor(UUID musicTrackId) {
        Objects.requireNonNull(
                musicTrackId,
                "musicTrackId must not be null"
        );

        return "music/tracks/" + musicTrackId + "/audio.mp3";
    }
}
