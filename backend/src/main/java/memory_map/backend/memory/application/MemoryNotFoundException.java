package memory_map.backend.memory.application;

public final class MemoryNotFoundException extends RuntimeException {

    private static final String MESSAGE = "Memory was not found";

    public MemoryNotFoundException() {
        super(MESSAGE);
    }
}
