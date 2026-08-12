package memory_map.backend.media.image;

public final class ImageProcessingException extends RuntimeException {

    private static final String MESSAGE = "Image could not be processed";

    public ImageProcessingException() {
        super(MESSAGE);
    }

    public ImageProcessingException(Throwable cause) {
        super(MESSAGE, cause);
    }
}
