package memory_map.backend.music.application;

public final class InvalidStorySoundtrackAudioRangeException
        extends RuntimeException {

    private static final String MESSAGE =
            "Story soundtrack audio range is invalid";

    private final long totalLength;

    public InvalidStorySoundtrackAudioRangeException(long totalLength) {
        super(MESSAGE);

        if (totalLength <= 0) {
            throw new IllegalArgumentException(
                    "totalLength must be positive"
            );
        }

        this.totalLength = totalLength;
    }

    public long totalLength() {
        return totalLength;
    }
}
