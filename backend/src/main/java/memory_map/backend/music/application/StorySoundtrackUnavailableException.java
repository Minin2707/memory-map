package memory_map.backend.music.application;

public final class StorySoundtrackUnavailableException
        extends RuntimeException {

    private static final String MESSAGE =
            "Story soundtrack could not be updated";

    public StorySoundtrackUnavailableException() {
        super(MESSAGE);
    }
}
