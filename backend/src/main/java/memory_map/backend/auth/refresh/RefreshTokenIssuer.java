package memory_map.backend.auth.refresh;

import java.time.Instant;
import java.util.UUID;

public interface RefreshTokenIssuer {

    default IssuedRefreshToken issue(
            UUID tokenId,
            UUID userId,
            Instant issuedAt
    ) {
        return issue(
                tokenId,
                tokenId,
                userId,
                issuedAt
        );
    }

    IssuedRefreshToken issue(
            UUID tokenId,
            UUID familyId,
            UUID userId,
            Instant issuedAt
    );

}
