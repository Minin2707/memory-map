package memory_map.backend.invite.application;

import java.net.URI;
import java.time.Instant;
import java.util.Locale;
import java.util.Objects;

public record CreatedInvite(

        URI inviteLink,

        Instant expiresAt

) {
    public CreatedInvite {
        Objects.requireNonNull(inviteLink, "inviteLink must not be null");
        Objects.requireNonNull(expiresAt, "expiresAt must not be null");

        if (!inviteLink.isAbsolute()) {
            throw new IllegalArgumentException(
                    "inviteLink must be absolute"
            );
        }

        String scheme = inviteLink.getScheme().toLowerCase(Locale.ROOT);
        if (!scheme.equals("https") && !scheme.equals("http")) {
            throw new IllegalArgumentException(
                    "inviteLink scheme must be http or https"
            );
        }

        if (inviteLink.getHost() == null) {
            throw new IllegalArgumentException(
                    "inviteLink host must not be null"
            );
        }
    }

    @Override
    public String toString() {
        return "CreatedInvite["
                + "inviteLink=<redacted>, "
                + "expiresAt=" + expiresAt
                + "]";
    }
}
