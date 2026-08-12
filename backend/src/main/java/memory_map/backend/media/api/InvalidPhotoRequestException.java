package memory_map.backend.media.api;

public final class InvalidPhotoRequestException extends RuntimeException {

    private static final String MESSAGE = "Invalid photo request";

    public InvalidPhotoRequestException() {
        super(MESSAGE);
    }

    public InvalidPhotoRequestException(Throwable cause) {
        super(MESSAGE, cause);
    }

    @Override
    public String toString() {
        return "InvalidPhotoRequestException[message=%s]"
                .formatted(MESSAGE);
    }
}
