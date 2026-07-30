package memory_map.backend.auth.refresh;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RawRefreshTokenTest {

    @Test
    void shouldCreateRawRefreshToken() {

        RawRefreshToken token = new RawRefreshToken("refresh-token-value");

        assertThat(token.value()).isEqualTo("refresh-token-value");
    }

    @Test
    void shouldRejectNullValue() {

        assertThatThrownBy(() -> new RawRefreshToken(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("value must not be null");
    }

    @Test
    void shouldRejectEmptyValue() {

        assertThatThrownBy(() -> new RawRefreshToken(""))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("value must not be blank");
    }

    @Test
    void shouldRejectWhitespaceValue() {

        assertThatThrownBy(() -> new RawRefreshToken("   "))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("value must not be blank");
    }

    @Test
    void shouldCompareByValue() {

        RawRefreshToken first = new RawRefreshToken("same-value");
        RawRefreshToken second = new RawRefreshToken("same-value");
        RawRefreshToken other = new RawRefreshToken("other-value");

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(other);
    }

    @Test
    void shouldProduceStableHashCode() {

        RawRefreshToken first = new RawRefreshToken("same-value");
        RawRefreshToken second = new RawRefreshToken("same-value");

        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldRedactValueInToString() {

        String rawValue = "refresh-token-value";
        RawRefreshToken token = new RawRefreshToken(rawValue);

        assertThat(token.toString())
                .isEqualTo("RawRefreshToken[REDACTED]")
                .doesNotContain(rawValue);
    }
}
