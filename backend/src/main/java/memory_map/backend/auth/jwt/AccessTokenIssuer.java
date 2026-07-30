package memory_map.backend.auth.jwt;

import java.time.Instant;
import java.util.UUID;

public interface AccessTokenIssuer {

    String issue(
            UUID userId,
            Instant issuedAt
    );

}
