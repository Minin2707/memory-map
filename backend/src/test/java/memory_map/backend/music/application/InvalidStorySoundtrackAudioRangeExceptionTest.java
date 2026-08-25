package memory_map.backend.music.application;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class InvalidStorySoundtrackAudioRangeExceptionTest {

    @Test
    void shouldHaveSafeMessage() {
        InvalidStorySoundtrackAudioRangeException exception =
                new InvalidStorySoundtrackAudioRangeException(4_096L);

        assertThat(exception)
                .hasMessage("Story soundtrack audio range is invalid");
        assertThat(exception.totalLength()).isEqualTo(4_096L);
        assertThat(exception.getMessage())
                .doesNotContain("storyId")
                .doesNotContain("musicTrackId")
                .doesNotContain("storageKey")
                .doesNotContain("Range")
                .doesNotContain("bytes=");
    }

    @Test
    void shouldRejectInvalidTotalLength() {
        org.assertj.core.api.Assertions.assertThatThrownBy(
                () -> new InvalidStorySoundtrackAudioRangeException(0L)
        ).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("totalLength must be positive");
    }
}
