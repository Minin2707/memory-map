package memory_map.backend.media.storage;

public interface StorageService {

    void store(StorageObjectWrite object);

    default void store(StorageStreamWrite object) {
        throw new UnsupportedOperationException(
                "Stream storage is not supported"
        );
    }

    /**
     * The caller owns and must close the returned content stream.
     */
    StoredObject read(StorageKey storageKey);

    /**
     * The caller owns and must close the returned content stream.
     */
    StoredObject readRange(
            StorageKey storageKey,
            StorageByteRange range
    );

    /**
     * Deleting a missing object is a successful no-op.
     */
    void delete(StorageKey storageKey);
}
