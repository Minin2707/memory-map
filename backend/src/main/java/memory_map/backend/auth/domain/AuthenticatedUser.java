package memory_map.backend.auth.domain;

import java.util.Objects;
import java.util.UUID;

public record AuthenticatedUser(

        UUID userId

) {
    public AuthenticatedUser {
        Objects.requireNonNull(userId, "userId must not be null");
    }
}
