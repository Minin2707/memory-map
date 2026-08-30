package memory_map.backend.story.application;

import java.util.Objects;

public record StoryPhotoPreview(

        String thumbnailUrl,

        String displayUrl

) {
    public StoryPhotoPreview {
        Objects.requireNonNull(thumbnailUrl, "thumbnailUrl must not be null");
        Objects.requireNonNull(displayUrl, "displayUrl must not be null");

        if (thumbnailUrl.isBlank()) {
            throw new IllegalArgumentException(
                    "thumbnailUrl must not be blank"
            );
        }

        if (displayUrl.isBlank()) {
            throw new IllegalArgumentException("displayUrl must not be blank");
        }
    }

    @Override
    public String toString() {
        return "StoryPhotoPreview[hasThumbnailUrl=true, hasDisplayUrl=true]";
    }
}
