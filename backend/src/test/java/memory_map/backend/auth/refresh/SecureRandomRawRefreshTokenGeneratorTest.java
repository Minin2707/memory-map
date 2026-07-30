package memory_map.backend.auth.refresh;

import org.junit.jupiter.api.Test;

import java.security.SecureRandom;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SecureRandomRawRefreshTokenGeneratorTest {

    private static final int TOKEN_BYTES = 32;

    @Test
    void shouldGenerateUrlSafeTokenWithoutPadding() {

        byte[] fixedBytes = fixedBytesStartingAt(0);
        SecureRandomRawRefreshTokenGenerator generator =
                new SecureRandomRawRefreshTokenGenerator(
                        new FixedBytesSecureRandom(fixedBytes)
                );

        RawRefreshToken token = generator.generate();

        assertThat(token.value())
                .isEqualTo(expectedTokenValue(fixedBytes))
                .doesNotContain("+")
                .doesNotContain("/")
                .doesNotContain("=");
    }

    @Test
    void shouldGenerateTokenFromExactly32RandomBytes() {

        byte[] fixedBytes = fixedBytesStartingAt(32);
        SecureRandomRawRefreshTokenGenerator generator =
                new SecureRandomRawRefreshTokenGenerator(
                        new FixedBytesSecureRandom(fixedBytes)
                );

        RawRefreshToken token = generator.generate();

        assertThat(token.value())
                .isEqualTo(expectedTokenValue(fixedBytes))
                .hasSize(43);
    }

    @Test
    void shouldGenerateDifferentTokensForDifferentRandomBytes() {

        SecureRandomRawRefreshTokenGenerator generator =
                new SecureRandomRawRefreshTokenGenerator(
                        new FixedBytesSecureRandom(
                                fixedBytesStartingAt(0),
                                fixedBytesStartingAt(1)
                        )
                );

        RawRefreshToken first = generator.generate();
        RawRefreshToken second = generator.generate();

        assertThat(first).isNotEqualTo(second);
    }

    @Test
    void shouldRejectNullSecureRandom() {

        assertThatThrownBy(() -> new SecureRandomRawRefreshTokenGenerator(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("secureRandom must not be null");
    }

    private static byte[] fixedBytesStartingAt(int start) {
        byte[] bytes = new byte[TOKEN_BYTES];

        for (int index = 0; index < bytes.length; index++) {
            bytes[index] = (byte) (start + index);
        }

        return bytes;
    }

    private static String expectedTokenValue(byte[] fixedBytes) {
        return Base64
                .getUrlEncoder()
                .withoutPadding()
                .encodeToString(fixedBytes);
    }

    private static final class FixedBytesSecureRandom extends SecureRandom {

        private final byte[][] fixedValues;
        private int index;

        private FixedBytesSecureRandom(byte[]... fixedValues) {
            this.fixedValues = fixedValues;
        }

        @Override
        public void nextBytes(byte[] bytes) {
            assertThat(bytes).hasSize(TOKEN_BYTES);
            assertThat(index).isLessThan(fixedValues.length);

            byte[] fixedValue = fixedValues[index];
            assertThat(fixedValue).hasSize(TOKEN_BYTES);

            System.arraycopy(
                    fixedValue,
                    0,
                    bytes,
                    0,
                    TOKEN_BYTES
            );
            index++;
        }
    }
}
