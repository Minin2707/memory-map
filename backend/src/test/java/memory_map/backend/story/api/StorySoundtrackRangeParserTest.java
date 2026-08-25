package memory_map.backend.story.api;

import memory_map.backend.music.application.StorySoundtrackAudioRange;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StorySoundtrackRangeParserTest {

    @Test
    void shouldReturnNullWhenHeaderIsAbsent() {
        assertThat(StorySoundtrackRangeParser.parse(null)).isNull();
    }

    @Test
    void shouldParseStartEndRanges() {
        assertThat(StorySoundtrackRangeParser.parse("bytes=0-0"))
                .isEqualTo(StorySoundtrackAudioRange.startEnd(0L, 0L));
        assertThat(StorySoundtrackRangeParser.parse("bytes=0-499"))
                .isEqualTo(StorySoundtrackAudioRange.startEnd(0L, 499L));
    }

    @Test
    void shouldParseOpenEndedRange() {
        assertThat(StorySoundtrackRangeParser.parse("bytes=500-"))
                .isEqualTo(StorySoundtrackAudioRange.openEnded(500L));
    }

    @Test
    void shouldParseSuffixRange() {
        assertThat(StorySoundtrackRangeParser.parse("bytes=-500"))
                .isEqualTo(StorySoundtrackAudioRange.suffix(500L));
    }

    @Test
    void shouldRejectMalformedRanges() {
        assertMalformed("nonsense");
        assertMalformed("items=1-2");
        assertMalformed("bytes=");
        assertMalformed("bytes=abc-def");
        assertMalformed("bytes=5-3");
        assertMalformed("bytes=0-499,1000-1499");
        assertMalformed("bytes=-");
        assertMalformed("bytes=-0");
        assertMalformed("bytes=--500");
        assertMalformed("bytes=1-2-3");
        assertMalformed("bytes=+1-2");
    }

    @Test
    void shouldRejectOverflowingNumbers() {
        assertMalformed("bytes=9223372036854775808-");
        assertMalformed("bytes=-9223372036854775808");
    }

    private static void assertMalformed(String headerValue) {
        assertThatThrownBy(() -> StorySoundtrackRangeParser.parse(headerValue))
                .isInstanceOf(
                        MalformedStorySoundtrackAudioRangeException.class
                )
                .hasMessage("Story soundtrack audio range is invalid");
    }
}
