package memory_map.backend.auth.jwt;

import memory_map.backend.auth.domain.AuthenticatedUser;

public interface AccessTokenVerifier {

    AuthenticatedUser verify(String accessToken);

}
