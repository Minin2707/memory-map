package memory_map.backend.music.application;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class StorySoundtrackUnavailableExceptionTest {

    @Test
    void shouldHaveSafeMessage() {
        StorySoundtrackUnavailableException exception =
                new StorySoundtrackUnavailableException();

        assertThat(exception)
                .hasMessage("Story soundtrack could not be updated");
        assertThat(exception.getMessage())
                .doesNotContain("storyId")
                .doesNotContain("musicTrackId")
                .doesNotContain("storageKey")
                .doesNotContain("DISABLED");
    }
}
