package memory_map.backend.auth.refresh;

import java.time.Instant;
import java.util.UUID;

public interface RefreshTokenRotationService {

    RefreshTokenRotationResult rotate(
            RawRefreshToken currentRefreshToken,
            UUID newRefreshTokenId,
            Instant currentTime
    );

}
