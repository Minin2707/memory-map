package memory_map.backend.auth.login;

import memory_map.backend.auth.domain.GoogleIdentity;

import java.time.Instant;
import java.util.UUID;

interface GoogleLoginTransaction {

    GoogleLoginResult login(
            GoogleIdentity identity,
            UUID newUserId,
            UUID newRefreshTokenId,
            Instant currentTime
    );

}
