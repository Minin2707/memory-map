package memory_map.backend.music.application;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class StorySoundtrackAudioUnavailableExceptionTest {

    @Test
    void shouldHaveSafeMessage() {
        StorySoundtrackAudioUnavailableException exception =
                new StorySoundtrackAudioUnavailableException();

        assertThat(exception)
                .hasMessage("Story soundtrack audio could not be found");
        assertThat(exception.getMessage())
                .doesNotContain("storyId")
                .doesNotContain("musicTrackId")
                .doesNotContain("storageKey")
                .doesNotContain("DISABLED");
    }
}
