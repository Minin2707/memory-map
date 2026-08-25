package memory_map.backend.music.application;

public final class StorySoundtrackAudioUnavailableException
        extends RuntimeException {

    private static final String MESSAGE =
            "Story soundtrack audio could not be found";

    public StorySoundtrackAudioUnavailableException() {
        super(MESSAGE);
    }
}
