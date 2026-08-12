package memory_map.backend.media.storage;

public interface StorageService {

    void store(StorageObjectWrite object);

    /**
     * The caller owns and must close the returned content stream.
     */
    StoredObject read(StorageKey storageKey);

    /**
     * Deleting a missing object is a successful no-op.
     */
    void delete(StorageKey storageKey);
}
