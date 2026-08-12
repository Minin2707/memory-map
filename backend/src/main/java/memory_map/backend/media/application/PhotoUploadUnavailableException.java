package memory_map.backend.media.application;

public final class PhotoUploadUnavailableException extends RuntimeException {

    private static final String MESSAGE = "Photo could not be uploaded";

    public PhotoUploadUnavailableException() {
        super(MESSAGE);
    }

    @Override
    public String toString() {
        return "PhotoUploadUnavailableException[message=%s]"
                .formatted(MESSAGE);
    }
}
