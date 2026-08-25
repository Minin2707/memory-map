package memory_map.backend.music.infrastructure.catalog;

import memory_map.backend.music.domain.MusicTrack;
import memory_map.backend.music.domain.MusicTrackStatus;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface MusicCatalogWriter {

    Optional<MusicTrack> findById(UUID id);

    Optional<UUID> findTrackIdByStorageKey(String storageKey);

    void insertDisabled(MusicTrack musicTrack);

    void updateMetadata(
            UUID id,
            String title,
            String artist,
            int sortOrder,
            Instant updatedAt
    );

    void updateStatus(
            UUID id,
            MusicTrackStatus status,
            Instant updatedAt
    );
}
