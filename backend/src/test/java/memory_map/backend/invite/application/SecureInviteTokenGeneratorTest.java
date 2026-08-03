package memory_map.backend.invite.application;

import org.junit.jupiter.api.Test;

import java.security.SecureRandom;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SecureInviteTokenGeneratorTest {

    private static final int TOKEN_BYTES = 32;

    @Test
    void shouldGenerateUrlSafeTokenWithoutPadding() {

        byte[] fixedBytes = fixedBytesStartingAt(0);
        SecureInviteTokenGenerator generator =
                new SecureInviteTokenGenerator(
                        new FixedBytesSecureRandom(fixedBytes)
                );

        String token = generator.generate();

        assertThat(token)
                .isEqualTo(expectedToken(fixedBytes))
                .doesNotContain("+")
                .doesNotContain("/")
                .doesNotContain("=");
    }

    @Test
    void shouldGenerateTokenFromExactly32RandomBytes() {

        byte[] fixedBytes = fixedBytesStartingAt(32);
        SecureInviteTokenGenerator generator =
                new SecureInviteTokenGenerator(
                        new FixedBytesSecureRandom(fixedBytes)
                );

        String token = generator.generate();

        assertThat(token).hasSize(43);
        assertThat(Base64.getUrlDecoder().decode(token))
                .hasSize(TOKEN_BYTES);
    }

    @Test
    void shouldReturnNonBlankToken() {

        SecureInviteTokenGenerator generator =
                new SecureInviteTokenGenerator(
                        new FixedBytesSecureRandom(fixedBytesStartingAt(64))
                );

        assertThat(generator.generate()).isNotBlank();
    }

    @Test
    void shouldGenerateDifferentTokensForDifferentRandomBytes() {

        SecureInviteTokenGenerator generator =
                new SecureInviteTokenGenerator(
                        new FixedBytesSecureRandom(
                                fixedBytesStartingAt(0),
                                fixedBytesStartingAt(1)
                        )
                );

        String first = generator.generate();
        String second = generator.generate();

        assertThat(first).isNotEqualTo(second);
    }

    @Test
    void shouldNotGenerateUuidFormattedToken() {

        SecureInviteTokenGenerator generator =
                new SecureInviteTokenGenerator(
                        new FixedBytesSecureRandom(fixedBytesStartingAt(0))
                );

        assertThat(generator.generate())
                .doesNotMatch("[0-9a-fA-F-]{36}");
    }

    @Test
    void shouldRejectNullSecureRandom() {

        assertThatThrownBy(() -> new SecureInviteTokenGenerator(null))
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

    private static String expectedToken(byte[] fixedBytes) {
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
