package memory_map.backend.media.storage;

import java.util.Arrays;
import java.util.Objects;

public final class StorageObjectWrite {

    private final StorageKey storageKey;
    private final byte[] content;
    private final String contentType;

    public StorageObjectWrite(
            StorageKey storageKey,
            byte[] content,
            String contentType
    ) {
        this.storageKey = Objects.requireNonNull(
                storageKey,
                "storageKey must not be null"
        );
        Objects.requireNonNull(content, "content must not be null");
        this.contentType = Objects.requireNonNull(
                contentType,
                "contentType must not be null"
        );

        if (content.length == 0) {
            throw new IllegalArgumentException("content must not be empty");
        }

        if (contentType.isBlank()) {
            throw new IllegalArgumentException("contentType must not be blank");
        }

        this.content = Arrays.copyOf(content, content.length);
    }

    public StorageKey storageKey() {
        return storageKey;
    }

    public byte[] content() {
        return Arrays.copyOf(content, content.length);
    }

    public long contentLength() {
        return content.length;
    }

    public String contentType() {
        return contentType;
    }

    @Override
    public boolean equals(Object object) {
        if (this == object) {
            return true;
        }

        if (!(object instanceof StorageObjectWrite other)) {
            return false;
        }

        return storageKey.equals(other.storageKey)
                && Arrays.equals(content, other.content)
                && contentType.equals(other.contentType);
    }

    @Override
    public int hashCode() {
        int result = storageKey.hashCode();
        result = 31 * result + Arrays.hashCode(content);
        result = 31 * result + contentType.hashCode();
        return result;
    }

    @Override
    public String toString() {
        return "StorageObjectWrite[hasStorageKey=true, contentLength=%d, hasContentType=true]"
                .formatted(content.length);
    }
}
