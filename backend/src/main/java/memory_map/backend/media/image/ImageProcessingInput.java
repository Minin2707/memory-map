package memory_map.backend.media.image;

import java.util.Arrays;
import java.util.Objects;

public final class ImageProcessingInput {

    private final byte[] content;
    private final String declaredContentType;

    public ImageProcessingInput(
            byte[] content,
            String declaredContentType
    ) {
        Objects.requireNonNull(content, "content must not be null");

        if (content.length == 0) {
            throw new IllegalArgumentException("content must not be empty");
        }

        if (declaredContentType != null && declaredContentType.isBlank()) {
            throw new IllegalArgumentException(
                    "declaredContentType must not be blank"
            );
        }

        this.content = Arrays.copyOf(content, content.length);
        this.declaredContentType = declaredContentType;
    }

    public byte[] content() {
        return Arrays.copyOf(content, content.length);
    }

    public long contentLength() {
        return content.length;
    }

    public String declaredContentType() {
        return declaredContentType;
    }

    @Override
    public boolean equals(Object object) {
        if (this == object) {
            return true;
        }

        if (!(object instanceof ImageProcessingInput other)) {
            return false;
        }

        return Arrays.equals(content, other.content)
                && Objects.equals(
                declaredContentType,
                other.declaredContentType
        );
    }

    @Override
    public int hashCode() {
        int result = Arrays.hashCode(content);
        result = 31 * result + Objects.hashCode(declaredContentType);
        return result;
    }

    @Override
    public String toString() {
        return "ImageProcessingInput[contentLength=%d, hasDeclaredContentType=%s]"
                .formatted(content.length, declaredContentType != null);
    }
}
