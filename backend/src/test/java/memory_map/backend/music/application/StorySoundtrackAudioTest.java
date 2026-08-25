package memory_map.backend.music.application;

import memory_map.backend.media.storage.StorageByteRange;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StorySoundtrackAudioTest {

    @Test
    void shouldExposeFullAudioMetadata() throws Exception {
        ByteArrayInputStream content = new ByteArrayInputStream(
                new byte[] {1, 2, 3}
        );

        StorySoundtrackAudio audio = new StorySoundtrackAudio(
                content,
                "audio/mpeg",
                3L,
                3L,
                null
        );

        assertThat(audio.content()).isSameAs(content);
        assertThat(audio.content().readAllBytes()).containsExactly(1, 2, 3);
        assertThat(audio.contentType()).isEqualTo("audio/mpeg");
        assertThat(audio.contentLength()).isEqualTo(3L);
        assertThat(audio.totalLength()).isEqualTo(3L);
        assertThat(audio.range()).isNull();
    }

    @Test
    void shouldExposeRangedAudioMetadata() {
        StorageByteRange range = new StorageByteRange(2L, 4L);

        StorySoundtrackAudio audio = new StorySoundtrackAudio(
                new ByteArrayInputStream(new byte[] {3, 4, 5, 6}),
                "audio/mpeg",
                4L,
                10L,
                range
        );

        assertThat(audio.contentType()).isEqualTo("audio/mpeg");
        assertThat(audio.contentLength()).isEqualTo(4L);
        assertThat(audio.totalLength()).isEqualTo(10L);
        assertThat(audio.range()).isSameAs(range);
    }

    @Test
    void shouldRejectInvalidConstruction() {
        assertThatThrownBy(() -> new StorySoundtrackAudio(
                null,
                "audio/mpeg",
                1L,
                1L,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("content must not be null");

        assertThatThrownBy(() -> new StorySoundtrackAudio(
                new ByteArrayInputStream(new byte[] {1}),
                null,
                1L,
                1L,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("contentType must not be null");

        assertThatThrownBy(() -> new StorySoundtrackAudio(
                new ByteArrayInputStream(new byte[] {1}),
                " ",
                1L,
                1L,
                null
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("contentType must not be blank");

        assertThatThrownBy(() -> new StorySoundtrackAudio(
                new ByteArrayInputStream(new byte[] {1}),
                "audio/mpeg",
                0L,
                1L,
                null
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("contentLength must be positive");

        assertThatThrownBy(() -> new StorySoundtrackAudio(
                new ByteArrayInputStream(new byte[] {1}),
                "audio/mpeg",
                1L,
                0L,
                null
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("totalLength must be positive");
    }

    @Test
    void shouldRejectInconsistentFullAndRangedMetadata() {
        assertThatThrownBy(() -> new StorySoundtrackAudio(
                new ByteArrayInputStream(new byte[] {1}),
                "audio/mpeg",
                1L,
                2L,
                null
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage(
                        "contentLength must equal totalLength for full content"
                );

        assertThatThrownBy(() -> new StorySoundtrackAudio(
                new ByteArrayInputStream(new byte[] {1}),
                "audio/mpeg",
                1L,
                10L,
                new StorageByteRange(0L, 2L)
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("contentLength must equal range length");

        assertThatThrownBy(() -> new StorySoundtrackAudio(
                new ByteArrayInputStream(new byte[] {1}),
                "audio/mpeg",
                1L,
                10L,
                new StorageByteRange(10L, 1L)
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("range offset must be within totalLength");

        assertThatThrownBy(() -> new StorySoundtrackAudio(
                new ByteArrayInputStream(new byte[] {1}),
                "audio/mpeg",
                2L,
                10L,
                new StorageByteRange(9L, 2L)
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("range must not exceed totalLength");
    }

    @Test
    void shouldHaveSafeToString() {
        StorySoundtrackAudio audio = new StorySoundtrackAudio(
                new ByteArrayInputStream(new byte[] {1}),
                "audio/mpeg",
                1L,
                1L,
                null
        );

        assertThat(audio.toString())
                .contains("contentLength=1")
                .contains("totalLength=1")
                .contains("hasContentType=true")
                .contains("hasRange=false")
                .doesNotContain("storageKey")
                .doesNotContain("music/")
                .doesNotContain("ByteArrayInputStream")
                .doesNotContain("audio/mpeg");
    }
}
