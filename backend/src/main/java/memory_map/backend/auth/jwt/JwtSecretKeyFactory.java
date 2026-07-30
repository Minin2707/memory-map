package memory_map.backend.auth.jwt;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.util.Base64;

final class JwtSecretKeyFactory {

    private static final String HMAC_SHA_256 = "HmacSHA256";
    private static final int MINIMUM_SECRET_BYTES = 32;
    private static final String INVALID_SECRET_MESSAGE =
            "JWT secret must be valid Base64 and at least 32 bytes";

    private JwtSecretKeyFactory() {
    }

    static SecretKey create(String secretBase64) {

        if (secretBase64 == null || secretBase64.isBlank()) {
            throw invalidSecret();
        }

        byte[] decodedSecret = decodedSecret(secretBase64);

        if (decodedSecret.length < MINIMUM_SECRET_BYTES) {
            throw invalidSecret();
        }

        return new SecretKeySpec(decodedSecret, HMAC_SHA_256);
    }

    private static byte[] decodedSecret(String secretBase64) {
        try {
            return Base64.getDecoder().decode(secretBase64);
        } catch (IllegalArgumentException exception) {
            throw invalidSecret(exception);
        }
    }

    private static IllegalArgumentException invalidSecret() {
        return new IllegalArgumentException(INVALID_SECRET_MESSAGE);
    }

    private static IllegalArgumentException invalidSecret(Throwable cause) {
        return new IllegalArgumentException(
                INVALID_SECRET_MESSAGE,
                cause
        );
    }
}
