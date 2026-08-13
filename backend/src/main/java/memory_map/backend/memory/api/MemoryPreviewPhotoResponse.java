package memory_map.backend.memory.api;

import memory_map.backend.memory.application.MemoryPreviewPhoto;

import java.util.Objects;
import java.util.UUID;

public record MemoryPreviewPhotoResponse(

        UUID mediaId,

        String thumbnailUrl

) {
    public static MemoryPreviewPhotoResponse from(
            MemoryPreviewPhoto previewPhoto
    ) {
        Objects.requireNonNull(
                previewPhoto,
                "previewPhoto must not be null"
        );

        return new MemoryPreviewPhotoResponse(
                previewPhoto.mediaId(),
                "/api/v1/media/%s/thumbnail".formatted(previewPhoto.mediaId())
        );
    }
}
