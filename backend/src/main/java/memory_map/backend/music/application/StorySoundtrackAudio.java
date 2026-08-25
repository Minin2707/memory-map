package memory_map.backend.music.application;

import memory_map.backend.media.storage.StorageByteRange;

import java.io.InputStream;
import java.util.Objects;

public final class StorySoundtrackAudio {

    private final InputStream content;
    private final String contentType;
    private final long contentLength;
    private final long totalLength;
    private final StorageByteRange range;

    public StorySoundtrackAudio(
            InputStream content,
            String contentType,
            long contentLength,
            long totalLength,
            StorageByteRange range
    ) {
        this.content = Objects.requireNonNull(
                content,
                "content must not be null"
        );
        this.contentType = Objects.requireNonNull(
                contentType,
                "contentType must not be null"
        );

        if (contentType.isBlank()) {
            throw new IllegalArgumentException("contentType must not be blank");
        }

        if (contentLength <= 0) {
            throw new IllegalArgumentException("contentLength must be positive");
        }

        if (totalLength <= 0) {
            throw new IllegalArgumentException("totalLength must be positive");
        }

        if (range == null) {
            if (contentLength != totalLength) {
                throw new IllegalArgumentException(
                        "contentLength must equal totalLength for full content"
                );
            }
        } else {
            validateRange(range, contentLength, totalLength);
        }

        this.contentLength = contentLength;
        this.totalLength = totalLength;
        this.range = range;
    }

    public InputStream content() {
        return content;
    }

    public String contentType() {
        return contentType;
    }

    public long contentLength() {
        return contentLength;
    }

    public long totalLength() {
        return totalLength;
    }

    public StorageByteRange range() {
        return range;
    }

    @Override
    public String toString() {
        return (
                "StorySoundtrackAudio[contentLength=%d, totalLength=%d, "
                        + "hasContentType=true, hasRange=%s]"
        ).formatted(contentLength, totalLength, range != null);
    }

    private static void validateRange(
            StorageByteRange range,
            long contentLength,
            long totalLength
    ) {
        if (contentLength != range.length()) {
            throw new IllegalArgumentException(
                    "contentLength must equal range length"
            );
        }

        if (range.offset() >= totalLength) {
            throw new IllegalArgumentException(
                    "range offset must be within totalLength"
            );
        }

        if (range.length() > totalLength - range.offset()) {
            throw new IllegalArgumentException(
                    "range must not exceed totalLength"
            );
        }
    }
}
