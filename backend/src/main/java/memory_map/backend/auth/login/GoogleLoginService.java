package memory_map.backend.auth.login;

import java.time.Instant;
import java.util.UUID;

public interface GoogleLoginService {

    GoogleLoginResult login(
            String googleIdToken,
            UUID newUserId,
            UUID newRefreshTokenId,
            Instant currentTime
    );

}
