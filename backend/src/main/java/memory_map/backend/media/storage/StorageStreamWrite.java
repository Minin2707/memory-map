package memory_map.backend.media.storage;

import java.io.InputStream;
import java.util.Objects;

public final class StorageStreamWrite {

    private final StorageKey storageKey;
    private final InputStream content;
    private final long contentLength;
    private final String contentType;

    public StorageStreamWrite(
            StorageKey storageKey,
            InputStream content,
            long contentLength,
            String contentType
    ) {
        this.storageKey = Objects.requireNonNull(
                storageKey,
                "storageKey must not be null"
        );
        this.content = Objects.requireNonNull(
                content,
                "content must not be null"
        );
        this.contentType = Objects.requireNonNull(
                contentType,
                "contentType must not be null"
        );

        if (contentLength <= 0) {
            throw new IllegalArgumentException(
                    "contentLength must be positive"
            );
        }

        if (contentType.isBlank()) {
            throw new IllegalArgumentException(
                    "contentType must not be blank"
            );
        }

        this.contentLength = contentLength;
    }

    public StorageKey storageKey() {
        return storageKey;
    }

    public InputStream content() {
        return content;
    }

    public long contentLength() {
        return contentLength;
    }

    public String contentType() {
        return contentType;
    }

    @Override
    public String toString() {
        return "StorageStreamWrite[hasStorageKey=true, contentLength=%d, hasContentType=true]"
                .formatted(contentLength);
    }
}
