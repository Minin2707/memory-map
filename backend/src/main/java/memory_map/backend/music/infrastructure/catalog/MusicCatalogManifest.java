package memory_map.backend.music.infrastructure.catalog;

import java.util.List;
import java.util.Objects;

public record MusicCatalogManifest(

        List<MusicCatalogManifestTrack> tracks

) {
    public MusicCatalogManifest {
        Objects.requireNonNull(tracks, "tracks must not be null");

        if (tracks.isEmpty()) {
            throw new IllegalArgumentException("tracks must not be empty");
        }

        tracks = List.copyOf(tracks);
    }
}
