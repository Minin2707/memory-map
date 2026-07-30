package memory_map.backend.auth.jwt;

import org.junit.jupiter.api.Test;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtSecretKeyFactoryTest {

    private static final String HMAC_SHA_256 = "HmacSHA256";
    private static final String INVALID_SECRET_MESSAGE =
            "JWT secret must be valid Base64 and at least 32 bytes";
    private static final byte[] VALID_SECRET =
            "0123456789abcdef0123456789abcdef"
                    .getBytes(StandardCharsets.UTF_8);
    private static final String VALID_SECRET_BASE64 =
            Base64.getEncoder().encodeToString(VALID_SECRET);

    @Test
    void shouldCreateHmacSha256KeyFromValidBase64Secret() {

        SecretKey key = JwtSecretKeyFactory.create(VALID_SECRET_BASE64);

        assertThat(key.getAlgorithm()).isEqualTo(HMAC_SHA_256);
        assertThat(key.getEncoded()).isEqualTo(VALID_SECRET);
    }

    @Test
    void shouldAcceptSecretLongerThan32Bytes() {

        byte[] secret = "0123456789abcdef0123456789abcdef-extra"
                .getBytes(StandardCharsets.UTF_8);
        String secretBase64 = Base64.getEncoder().encodeToString(secret);

        SecretKey key = JwtSecretKeyFactory.create(secretBase64);

        assertThat(key.getAlgorithm()).isEqualTo(HMAC_SHA_256);
        assertThat(key.getEncoded()).isEqualTo(secret);
    }

    @Test
    void shouldRejectNullSecret() {

        assertInvalidSecret(() -> JwtSecretKeyFactory.create(null));
    }

    @Test
    void shouldRejectEmptySecret() {

        assertInvalidSecret(() -> JwtSecretKeyFactory.create(""));
    }

    @Test
    void shouldRejectWhitespaceSecret() {

        assertInvalidSecret(() -> JwtSecretKeyFactory.create("   "));
    }

    @Test
    void shouldRejectInvalidBase64Secret() {

        assertThatThrownBy(() -> JwtSecretKeyFactory.create("not-base64"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage(INVALID_SECRET_MESSAGE)
                .hasCauseInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void shouldRejectSecretShorterThan32Bytes() {

        byte[] secret = "short-secret".getBytes(StandardCharsets.UTF_8);
        String secretBase64 = Base64.getEncoder().encodeToString(secret);

        assertInvalidSecret(() -> JwtSecretKeyFactory.create(secretBase64));
    }

    private static void assertInvalidSecret(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage(INVALID_SECRET_MESSAGE);
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();

    }
}
