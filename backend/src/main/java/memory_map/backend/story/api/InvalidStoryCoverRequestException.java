package memory_map.backend.story.api;

public final class InvalidStoryCoverRequestException extends RuntimeException {

    private static final String MESSAGE = "Invalid story cover request";

    public InvalidStoryCoverRequestException(Throwable cause) {
        super(MESSAGE, cause);
    }
}
