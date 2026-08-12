package memory_map.backend.media.image;

public enum InvalidImageReason {
    EMPTY,
    TOO_LARGE,
    UNSUPPORTED_TYPE,
    MIME_MISMATCH,
    INVALID_IMAGE,
    DIMENSIONS_EXCEEDED
}
