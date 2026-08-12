package memory_map.backend.media.application;

public final class MediaUnavailableException extends RuntimeException {

    private static final String MESSAGE = "Media could not be found";

    public MediaUnavailableException() {
        super(MESSAGE);
    }

    @Override
    public String toString() {
        return "MediaUnavailableException[message=%s]"
                .formatted(MESSAGE);
    }
}
