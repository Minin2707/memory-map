package memory_map.backend.media.application;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class MediaUnavailableExceptionTest {

    @Test
    void shouldHaveSafeMessageAndToString() {
        MediaUnavailableException exception = new MediaUnavailableException();

        assertThat(exception).hasMessage("Media could not be found");
        assertThat(exception.toString())
                .isEqualTo("MediaUnavailableException[message=Media could not be found]")
                .doesNotContain("storage")
                .doesNotContain("bucket")
                .doesNotContain("MinIO")
                .doesNotContain("00000000-0000-0000-0000-000000000001");
    }
}
