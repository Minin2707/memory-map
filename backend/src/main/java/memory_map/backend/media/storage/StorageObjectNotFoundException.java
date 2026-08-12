package memory_map.backend.media.storage;

public final class StorageObjectNotFoundException extends StorageException {

    private static final String MESSAGE = "Storage object was not found";

    public StorageObjectNotFoundException() {
        super(MESSAGE);
    }
}
