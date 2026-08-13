package memory_map.backend.memory.application;

import java.util.Objects;
import java.util.UUID;

public record MemoryPreviewPhoto(

        UUID mediaId

) {
    public MemoryPreviewPhoto {
        Objects.requireNonNull(mediaId, "mediaId must not be null");
    }

    @Override
    public String toString() {
        return "MemoryPreviewPhoto[hasMediaId=true]";
    }
}
