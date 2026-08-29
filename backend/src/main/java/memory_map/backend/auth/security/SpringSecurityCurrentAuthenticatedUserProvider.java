package memory_map.backend.auth.security;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.user.repository.UserRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

import java.util.Objects;
import java.util.UUID;

public final class SpringSecurityCurrentAuthenticatedUserProvider
        implements CurrentAuthenticatedUserProvider {

    private static final String USER_UNAVAILABLE_MESSAGE =
            "Authenticated user is unavailable";

    private final UserRepository userRepository;

    public SpringSecurityCurrentAuthenticatedUserProvider() {
        this.userRepository = null;
    }

    public SpringSecurityCurrentAuthenticatedUserProvider(
            UserRepository userRepository
    ) {
        this.userRepository = Objects.requireNonNull(
                userRepository,
                "userRepository must not be null"
        );
    }

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
            UUID userId = UUID.fromString(subject);

            if (
                    userRepository != null &&
                            !userRepository.existsActiveById(userId)
            ) {
                throw userUnavailable();
            }

            return new AuthenticatedUser(userId);
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
