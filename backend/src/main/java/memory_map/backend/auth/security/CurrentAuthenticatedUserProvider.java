package memory_map.backend.auth.security;

import memory_map.backend.auth.domain.AuthenticatedUser;

public interface CurrentAuthenticatedUserProvider {

    AuthenticatedUser getCurrentUser();

}
