package memory_map.backend.auth.refresh;

import java.time.Instant;

public interface RefreshTokenLogoutService {

    void logout(
            RawRefreshToken refreshToken,
            Instant currentTime
    );

}
