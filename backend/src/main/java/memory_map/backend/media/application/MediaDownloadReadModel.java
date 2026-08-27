package memory_map.backend.media.application;

import java.util.Objects;

public record MediaDownloadReadModel(

        String displayStorageKey,

        long displayFileSize,

        String thumbnailStorageKey,

        long thumbnailFileSize,

        String mimeType

) {
    public MediaDownloadReadModel {
        Objects.requireNonNull(
                displayStorageKey,
                "displayStorageKey must not be null"
        );
        Objects.requireNonNull(
                thumbnailStorageKey,
                "thumbnailStorageKey must not be null"
        );
        Objects.requireNonNull(mimeType, "mimeType must not be null");

        if (displayStorageKey.isBlank()) {
            throw new IllegalArgumentException(
                    "displayStorageKey must not be blank"
            );
        }

        if (thumbnailStorageKey.isBlank()) {
            throw new IllegalArgumentException(
                    "thumbnailStorageKey must not be blank"
            );
        }

        if (displayStorageKey.equals(thumbnailStorageKey)) {
            throw new IllegalArgumentException(
                    "displayStorageKey and thumbnailStorageKey must differ"
            );
        }

        if (displayFileSize <= 0) {
            throw new IllegalArgumentException(
                    "displayFileSize must be positive"
            );
        }

        if (thumbnailFileSize <= 0) {
            throw new IllegalArgumentException(
                    "thumbnailFileSize must be positive"
            );
        }

        if (mimeType.isBlank()) {
            throw new IllegalArgumentException("mimeType must not be blank");
        }
    }

    public String storageKey(MediaRepresentation representation) {
        Objects.requireNonNull(
                representation,
                "representation must not be null"
        );

        return switch (representation) {
            case DISPLAY -> displayStorageKey;
            case THUMBNAIL -> thumbnailStorageKey;
        };
    }

    public long contentLength(MediaRepresentation representation) {
        Objects.requireNonNull(
                representation,
                "representation must not be null"
        );

        return switch (representation) {
            case DISPLAY -> displayFileSize;
            case THUMBNAIL -> thumbnailFileSize;
        };
    }

    @Override
    public String toString() {
        return "MediaDownloadReadModel[hasDisplay=true, hasThumbnail=true, hasMimeType=true]";
    }
}
