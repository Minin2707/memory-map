package memory_map.backend.media.image;

import java.util.Objects;

public record ProcessedPhoto(

        ProcessedImage display,

        ProcessedImage thumbnail,

        String mimeType

) {
    public ProcessedPhoto {
        Objects.requireNonNull(display, "display must not be null");
        Objects.requireNonNull(thumbnail, "thumbnail must not be null");
        Objects.requireNonNull(mimeType, "mimeType must not be null");

        if (mimeType.isBlank()) {
            throw new IllegalArgumentException("mimeType must not be blank");
        }
    }

    public long displayFileSize() {
        return display.fileSize();
    }

    public long thumbnailFileSize() {
        return thumbnail.fileSize();
    }

    @Override
    public String toString() {
        return "ProcessedPhoto[hasDisplay=true, hasThumbnail=true, hasMimeType=true]";
    }
}
