package memory_map.backend.media.storage;

public class StorageException extends RuntimeException {

    private static final String MESSAGE = "Storage operation failed";

    public StorageException() {
        super(MESSAGE);
    }

    public StorageException(Throwable cause) {
        super(MESSAGE, cause);
    }

    protected StorageException(String message) {
        super(message);
    }

    protected StorageException(String message, Throwable cause) {
        super(message, cause);
    }
}
