package memory_map.backend.auth.refresh;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Objects;

public class Sha256RefreshTokenHasher implements RefreshTokenHasher {

    private static final String SHA_256 = "SHA-256";

    private static final String HASHING_FAILED_MESSAGE =
            "Refresh token hashing failed";

    @Override
    public String hash(RawRefreshToken rawToken) {
        Objects.requireNonNull(
                rawToken,
                "rawToken must not be null"
        );

        try {
            MessageDigest messageDigest =
                    MessageDigest.getInstance(SHA_256);
            byte[] hashBytes = messageDigest.digest(
                    rawToken.value().getBytes(StandardCharsets.UTF_8)
            );

            return HexFormat.of().formatHex(hashBytes);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(
                    HASHING_FAILED_MESSAGE,
                    exception
            );
        }
    }
}
