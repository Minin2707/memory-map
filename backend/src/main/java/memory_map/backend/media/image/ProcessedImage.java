package memory_map.backend.media.image;

import java.util.Arrays;
import java.util.Objects;

public final class ProcessedImage {

    private final byte[] content;

    public ProcessedImage(byte[] content) {
        Objects.requireNonNull(content, "content must not be null");

        if (content.length == 0) {
            throw new IllegalArgumentException("content must not be empty");
        }

        this.content = Arrays.copyOf(content, content.length);
    }

    public byte[] content() {
        return Arrays.copyOf(content, content.length);
    }

    public long fileSize() {
        return content.length;
    }

    @Override
    public boolean equals(Object object) {
        if (this == object) {
            return true;
        }

        if (!(object instanceof ProcessedImage other)) {
            return false;
        }

        return Arrays.equals(content, other.content);
    }

    @Override
    public int hashCode() {
        return Arrays.hashCode(content);
    }

    @Override
    public String toString() {
        return "ProcessedImage[fileSize=%d]".formatted(content.length);
    }
}
