package memory_map.backend.music.infrastructure.catalog;

import memory_map.backend.music.domain.MusicTrackStatus;

import java.nio.file.Path;
import java.util.Objects;
import java.util.UUID;

public record MusicCatalogManifestTrack(

        UUID id,

        String title,

        String artist,

        int durationSeconds,

        int sortOrder,

        Path sourceFile,

        String sourceFileName,

        String storageKey,

        String mimeType,

        long fileSize,

        String sha256,

        MusicTrackStatus desiredStatus,

        MusicCatalogLegalStatus legalStatus

) {
    public MusicCatalogManifestTrack {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(title, "title must not be null");
        Objects.requireNonNull(artist, "artist must not be null");
        Objects.requireNonNull(sourceFile, "sourceFile must not be null");
        Objects.requireNonNull(
                sourceFileName,
                "sourceFileName must not be null"
        );
        Objects.requireNonNull(storageKey, "storageKey must not be null");
        Objects.requireNonNull(mimeType, "mimeType must not be null");
        Objects.requireNonNull(sha256, "sha256 must not be null");
        Objects.requireNonNull(
                desiredStatus,
                "desiredStatus must not be null"
        );
        Objects.requireNonNull(legalStatus, "legalStatus must not be null");

        if (title.isBlank()) {
            throw new IllegalArgumentException("title must not be blank");
        }

        if (artist.isBlank()) {
            throw new IllegalArgumentException("artist must not be blank");
        }

        if (durationSeconds <= 0) {
            throw new IllegalArgumentException(
                    "durationSeconds must be positive"
            );
        }

        if (sortOrder < 0) {
            throw new IllegalArgumentException(
                    "sortOrder must not be negative"
            );
        }

        if (sourceFileName.isBlank()) {
            throw new IllegalArgumentException(
                    "sourceFileName must not be blank"
            );
        }

        if (storageKey.isBlank()) {
            throw new IllegalArgumentException("storageKey must not be blank");
        }

        if (mimeType.isBlank()) {
            throw new IllegalArgumentException("mimeType must not be blank");
        }

        if (fileSize <= 0) {
            throw new IllegalArgumentException("fileSize must be positive");
        }

        if (sha256.isBlank()) {
            throw new IllegalArgumentException("sha256 must not be blank");
        }
    }

    public boolean shouldBeActive() {
        return legalStatus == MusicCatalogLegalStatus.APPROVED
                && desiredStatus == MusicTrackStatus.ACTIVE;
    }

    @Override
    public String toString() {
        return (
                "MusicCatalogManifestTrack[id=%s, title=%s, artist=%s, "
                        + "durationSeconds=%d, sortOrder=%d, "
                        + "sourceFileName=%s, hasStorageKey=%s, "
                        + "mimeType=%s, fileSize=%d, desiredStatus=%s, "
                        + "legalStatus=%s]"
        ).formatted(
                id,
                title,
                artist,
                durationSeconds,
                sortOrder,
                sourceFileName,
                !storageKey.isBlank(),
                mimeType,
                fileSize,
                desiredStatus,
                legalStatus
        );
    }
}
