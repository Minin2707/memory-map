package memory_map.backend.media.api;

import memory_map.backend.media.domain.MediaFile;
import memory_map.backend.media.domain.MediaType;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record MediaResponse(

        UUID id,

        UUID memoryId,

        MediaType mediaType,

        long displayFileSize,

        long thumbnailFileSize,

        String mimeType,

        Instant createdAt,

        String thumbnailUrl,

        String displayUrl

) {
    public static MediaResponse from(MediaFile mediaFile) {
        Objects.requireNonNull(mediaFile, "mediaFile must not be null");

        return new MediaResponse(
                mediaFile.id(),
                mediaFile.memoryId(),
                mediaFile.type(),
                mediaFile.displayFileSize(),
                mediaFile.thumbnailFileSize(),
                mediaFile.mimeType(),
                mediaFile.createdAt(),
                "/api/v1/media/%s/thumbnail".formatted(mediaFile.id()),
                "/api/v1/media/%s/display".formatted(mediaFile.id())
        );
    }
}
