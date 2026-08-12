package memory_map.backend.media.application;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class MediaDeletionUnavailableExceptionTest {

    @Test
    void shouldHaveSafeMessage() {
        MediaDeletionUnavailableException exception =
                new MediaDeletionUnavailableException();

        assertThat(exception)
                .hasMessage("Media could not be deleted");
        assertThat(exception.toString())
                .contains("Media could not be deleted")
                .doesNotContain(UUID.randomUUID().toString())
                .doesNotContain("storage")
                .doesNotContain("bucket")
                .doesNotContain("MinIO")
                .doesNotContain("role")
                .doesNotContain("user");
    }
}
