package memory_map.backend.media.image;

import java.util.Objects;

public final class InvalidImageException extends RuntimeException {

    private static final String MESSAGE = "Image is invalid";

    private final InvalidImageReason reason;

    public InvalidImageException(InvalidImageReason reason) {
        super(MESSAGE);
        this.reason = Objects.requireNonNull(
                reason,
                "reason must not be null"
        );
    }

    public InvalidImageReason reason() {
        return reason;
    }

    @Override
    public String toString() {
        return "InvalidImageException[reason=%s]".formatted(reason);
    }
}
