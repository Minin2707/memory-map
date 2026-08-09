package memory_map.backend.memory.application;

public final class MemoryCreationUnavailableException extends RuntimeException {

    private static final String MESSAGE = "Memory could not be created";

    public MemoryCreationUnavailableException() {
        super(MESSAGE);
    }
}
