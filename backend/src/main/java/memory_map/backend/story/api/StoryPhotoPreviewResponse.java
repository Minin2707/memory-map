package memory_map.backend.story.api;

import memory_map.backend.story.application.StoryPhotoPreview;

import java.util.Objects;

public record StoryPhotoPreviewResponse(

        String thumbnailUrl,

        String displayUrl

) {
    public static StoryPhotoPreviewResponse from(
            StoryPhotoPreview previewPhoto
    ) {
        Objects.requireNonNull(
                previewPhoto,
                "previewPhoto must not be null"
        );

        return new StoryPhotoPreviewResponse(
                previewPhoto.thumbnailUrl(),
                previewPhoto.displayUrl()
        );
    }
}
