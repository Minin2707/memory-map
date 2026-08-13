package memory_map.backend.story.application;

import java.util.Objects;
import java.util.UUID;

public record StoryPhotoPreview(

        UUID mediaId

) {
    public StoryPhotoPreview {
        Objects.requireNonNull(mediaId, "mediaId must not be null");
    }

    @Override
    public String toString() {
        return "StoryPhotoPreview[hasMediaId=true]";
    }
}
