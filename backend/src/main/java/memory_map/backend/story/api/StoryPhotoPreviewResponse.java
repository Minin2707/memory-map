package memory_map.backend.story.api;

import memory_map.backend.story.application.StoryPhotoPreview;

import java.util.Objects;
import java.util.UUID;

public record StoryPhotoPreviewResponse(

        UUID mediaId,

        String thumbnailUrl

) {
    public static StoryPhotoPreviewResponse from(
            StoryPhotoPreview previewPhoto
    ) {
        Objects.requireNonNull(
                previewPhoto,
                "previewPhoto must not be null"
        );

        return new StoryPhotoPreviewResponse(
                previewPhoto.mediaId(),
                "/api/v1/media/%s/thumbnail".formatted(previewPhoto.mediaId())
        );
    }
}
