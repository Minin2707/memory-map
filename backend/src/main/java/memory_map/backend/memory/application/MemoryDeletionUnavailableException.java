package memory_map.backend.memory.application;

public final class MemoryDeletionUnavailableException extends RuntimeException {

    private static final String MESSAGE = "Memory could not be deleted";

    public MemoryDeletionUnavailableException() {
        super(MESSAGE);
    }
}
