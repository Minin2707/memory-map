package memory_map.backend.auth.refresh;

import java.security.SecureRandom;
import java.util.Base64;
import java.util.Objects;

public class SecureRandomRawRefreshTokenGenerator
        implements RawRefreshTokenGenerator {

    private static final int TOKEN_BYTES = 32;

    private final SecureRandom secureRandom;

    public SecureRandomRawRefreshTokenGenerator(
            SecureRandom secureRandom
    ) {
        this.secureRandom = Objects.requireNonNull(
                secureRandom,
                "secureRandom must not be null"
        );
    }

    @Override
    public RawRefreshToken generate() {
        byte[] randomBytes = new byte[TOKEN_BYTES];
        secureRandom.nextBytes(randomBytes);

        String tokenValue = Base64
                .getUrlEncoder()
                .withoutPadding()
                .encodeToString(randomBytes);

        return new RawRefreshToken(tokenValue);
    }
}
