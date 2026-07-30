package memory_map.backend.auth.security;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

import java.util.UUID;

public final class SpringSecurityCurrentAuthenticatedUserProvider
        implements CurrentAuthenticatedUserProvider {

    private static final String USER_UNAVAILABLE_MESSAGE =
            "Authenticated user is unavailable";

    @Override
    public AuthenticatedUser getCurrentUser() {
        Authentication authentication =
                SecurityContextHolder
                        .getContext()
                        .getAuthentication();

        if (
                authentication == null
                        || !authentication.isAuthenticated()
                        || !(authentication
                        instanceof JwtAuthenticationToken jwtAuthentication)
        ) {
            throw userUnavailable();
        }

        Jwt jwt = jwtAuthentication.getToken();
        String subject = jwt.getSubject();

        if (subject == null || subject.isBlank()) {
            throw userUnavailable();
        }

        try {
            return new AuthenticatedUser(
                    UUID.fromString(subject)
            );
        } catch (IllegalArgumentException exception) {
            throw userUnavailable(exception);
        }
    }

    private static CurrentAuthenticatedUserException userUnavailable() {
        return new CurrentAuthenticatedUserException(
                USER_UNAVAILABLE_MESSAGE
        );
    }

    private static CurrentAuthenticatedUserException userUnavailable(
            Throwable cause
    ) {
        return new CurrentAuthenticatedUserException(
                USER_UNAVAILABLE_MESSAGE,
                cause
        );
    }
}
