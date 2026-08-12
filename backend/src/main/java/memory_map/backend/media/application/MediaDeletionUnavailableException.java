package memory_map.backend.media.application;

public final class MediaDeletionUnavailableException extends RuntimeException {

    private static final String MESSAGE = "Media could not be deleted";

    public MediaDeletionUnavailableException() {
        super(MESSAGE);
    }

    @Override
    public String toString() {
        return "MediaDeletionUnavailableException[message=%s]"
                .formatted(MESSAGE);
    }
}
