package memory_map.backend.music.application;

import memory_map.backend.media.storage.StorageByteRange;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.catchThrowable;

class StorySoundtrackAudioRangeTest {

    @Test
    void shouldNormalizeStartEndRangeAndClampEnd() {
        assertThat(StorySoundtrackAudioRange.startEnd(1L, 3L)
                .normalize(10L))
                .isEqualTo(new StorageByteRange(1L, 3L));

        assertThat(StorySoundtrackAudioRange.startEnd(8L, 99L)
                .normalize(10L))
                .isEqualTo(new StorageByteRange(8L, 2L));
    }

    @Test
    void shouldNormalizeOpenEndedRange() {
        assertThat(StorySoundtrackAudioRange.openEnded(6L)
                .normalize(10L))
                .isEqualTo(new StorageByteRange(6L, 4L));
    }

    @Test
    void shouldNormalizeSuffixRange() {
        assertThat(StorySoundtrackAudioRange.suffix(3L)
                .normalize(10L))
                .isEqualTo(new StorageByteRange(7L, 3L));

        assertThat(StorySoundtrackAudioRange.suffix(10L)
                .normalize(10L))
                .isEqualTo(new StorageByteRange(0L, 10L));

        assertThat(StorySoundtrackAudioRange.suffix(20L)
                .normalize(10L))
                .isEqualTo(new StorageByteRange(0L, 10L));
    }

    @Test
    void shouldRejectUnsatisfiableRangeWithTotalLength() {
        Throwable thrown = catchThrowable(
                () -> StorySoundtrackAudioRange.openEnded(10L).normalize(10L)
        );

        assertThat(thrown)
                .isInstanceOf(InvalidStorySoundtrackAudioRangeException.class);
        assertThat(
                ((InvalidStorySoundtrackAudioRangeException) thrown)
                        .totalLength()
        ).isEqualTo(10L);
    }

    @Test
    void shouldRejectInvalidConstruction() {
        assertThatThrownBy(() -> StorySoundtrackAudioRange.startEnd(-1L, 1L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("start must not be negative");

        assertThatThrownBy(() -> StorySoundtrackAudioRange.startEnd(2L, 1L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("endInclusive must not be before start");

        assertThatThrownBy(() -> StorySoundtrackAudioRange.openEnded(-1L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("start must not be negative");

        assertThatThrownBy(() -> StorySoundtrackAudioRange.suffix(0L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("suffixLength must be positive");
    }

    @Test
    void shouldSupportEqualityAndSafeToString() {
        StorySoundtrackAudioRange range =
                StorySoundtrackAudioRange.startEnd(0L, 1L);

        assertThat(range)
                .isEqualTo(StorySoundtrackAudioRange.startEnd(0L, 1L))
                .hasSameHashCodeAs(
                        StorySoundtrackAudioRange.startEnd(0L, 1L)
                )
                .isNotEqualTo(StorySoundtrackAudioRange.openEnded(0L));
        assertThat(range.toString())
                .contains("START_END")
                .doesNotContain("bytes=")
                .doesNotContain("storageKey");
    }
}
