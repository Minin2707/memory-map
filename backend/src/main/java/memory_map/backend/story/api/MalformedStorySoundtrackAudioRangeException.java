package memory_map.backend.story.api;

final class MalformedStorySoundtrackAudioRangeException
        extends RuntimeException {

    private static final String MESSAGE =
            "Story soundtrack audio range is invalid";

    MalformedStorySoundtrackAudioRangeException() {
        super(MESSAGE);
    }
}
