package memory_map.backend.auth.refresh;

import java.time.Instant;
import java.util.UUID;

public interface RefreshTokenIssuer {

    IssuedRefreshToken issue(
            UUID tokenId,
            UUID userId,
            Instant issuedAt
    );

}
