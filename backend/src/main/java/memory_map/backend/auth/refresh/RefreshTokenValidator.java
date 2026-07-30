package memory_map.backend.auth.refresh;

import memory_map.backend.auth.domain.RefreshToken;

import java.time.Instant;

public interface RefreshTokenValidator {

    void validate(
            RefreshToken refreshToken,
            Instant currentTime
    );

}
