package memory_map.backend.memory.application;

public final class MemoryUpdateUnavailableException extends RuntimeException {

    private static final String MESSAGE = "Memory could not be updated";

    public MemoryUpdateUnavailableException() {
        super(MESSAGE);
    }
}
