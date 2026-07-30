package memory_map.backend.auth.refresh;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class Sha256RefreshTokenHasherTest {

    private static final String ABC_SHA_256_HEX =
            "ba7816bf8f01cfea414140de5dae2223"
                    + "b00361a396177a9cb410ff61f20015ad";

    @Test
    void shouldHashRawTokenWithSha256() {

        String hash = new Sha256RefreshTokenHasher()
                .hash(new RawRefreshToken("abc"));

        assertThat(hash).isEqualTo(ABC_SHA_256_HEX);
    }

    @Test
    void shouldReturnStableLowercaseHexHash() {

        Sha256RefreshTokenHasher hasher = new Sha256RefreshTokenHasher();
        RawRefreshToken token = new RawRefreshToken("refresh-token-value");

        String first = hasher.hash(token);
        String second = hasher.hash(token);

        assertThat(first).isEqualTo(second);
        assertThat(first).matches("[0-9a-f]{64}");
    }

    @Test
    void shouldReturnSixtyFourCharacterHash() {

        String hash = new Sha256RefreshTokenHasher()
                .hash(new RawRefreshToken("refresh-token-value"));

        assertThat(hash).hasSize(64);
    }

    @Test
    void shouldReturnDifferentHashesForDifferentTokens() {

        Sha256RefreshTokenHasher hasher = new Sha256RefreshTokenHasher();

        String first = hasher.hash(new RawRefreshToken("first-token"));
        String second = hasher.hash(new RawRefreshToken("second-token"));

        assertThat(first).isNotEqualTo(second);
    }

    @Test
    void shouldRejectNullRawToken() {

        assertThatThrownBy(() -> new Sha256RefreshTokenHasher().hash(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("rawToken must not be null");
    }
}
