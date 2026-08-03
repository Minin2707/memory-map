package memory_map.backend.invite.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Objects;

public class Sha256InviteTokenHasher implements InviteTokenHasher {

    private static final String SHA_256 = "SHA-256";

    private static final String HASHING_FAILED_MESSAGE =
            "Invite token hashing failed";

    @Override
    public String hash(String rawToken) {
        Objects.requireNonNull(rawToken, "rawToken must not be null");

        if (rawToken.isBlank()) {
            throw new IllegalArgumentException(
                    "rawToken must not be blank"
            );
        }

        try {
            MessageDigest messageDigest =
                    MessageDigest.getInstance(SHA_256);
            byte[] hashBytes = messageDigest.digest(
                    rawToken.getBytes(StandardCharsets.UTF_8)
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
