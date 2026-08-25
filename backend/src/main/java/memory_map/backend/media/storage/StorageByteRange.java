package memory_map.backend.media.storage;

public record StorageByteRange(

        long offset,

        long length

) {
    public StorageByteRange {
        if (offset < 0) {
            throw new IllegalArgumentException(
                    "offset must not be negative"
            );
        }

        if (length <= 0) {
            throw new IllegalArgumentException("length must be positive");
        }
    }
}
