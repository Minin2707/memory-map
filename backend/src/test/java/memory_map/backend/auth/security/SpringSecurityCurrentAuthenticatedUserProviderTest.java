package memory_map.backend.auth.security;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SpringSecurityCurrentAuthenticatedUserProviderTest {

    private static final String USER_UNAVAILABLE_MESSAGE =
            "Authenticated user is unavailable";
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final Instant ISSUED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant EXPIRES_AT =
            Instant.parse("2026-01-01T10:15:00Z");

    private final SpringSecurityCurrentAuthenticatedUserProvider provider =
            new SpringSecurityCurrentAuthenticatedUserProvider();

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void shouldReturnAuthenticatedUserFromJwtSubject() {

        setAuthentication(
                jwtAuthentication(
                        jwtWithSubject(USER_ID.toString())
                )
        );

        AuthenticatedUser currentUser = provider.getCurrentUser();

        assertThat(currentUser).isEqualTo(new AuthenticatedUser(USER_ID));
    }

    @Test
    void shouldReturnInternalUserUuid() {

        setAuthentication(
                jwtAuthentication(
                        jwtWithSubject(USER_ID.toString())
                )
        );

        AuthenticatedUser currentUser = provider.getCurrentUser();

        assertThat(currentUser.userId()).isEqualTo(USER_ID);
    }

    @Test
    void shouldRejectMissingAuthentication() {

        SecurityContextHolder.clearContext();

        assertUnavailableState(() -> provider.getCurrentUser());
    }

    @Test
    void shouldRejectUnauthenticatedAuthentication() {

        setAuthentication(
                UsernamePasswordAuthenticationToken.unauthenticated(
                        "principal",
                        "credentials"
                )
        );

        assertUnavailableState(() -> provider.getCurrentUser());
    }

    @Test
    void shouldRejectNonJwtAuthentication() {

        setAuthentication(
                UsernamePasswordAuthenticationToken.authenticated(
                        "principal",
                        "credentials",
                        List.of(new SimpleGrantedAuthority("ROLE_TEST"))
                )
        );

        assertUnavailableState(() -> provider.getCurrentUser());
    }

    @Test
    void shouldRejectJwtWithoutSubject() {

        setAuthentication(
                jwtAuthentication(jwtWithoutSubject())
        );

        assertUnavailableState(() -> provider.getCurrentUser());
    }

    @Test
    void shouldRejectJwtWithBlankSubject() {

        setAuthentication(
                jwtAuthentication(jwtWithSubject("   "))
        );

        assertUnavailableState(() -> provider.getCurrentUser());
    }

    @Test
    void shouldRejectJwtWithNonUuidSubject() {

        String subject = "not-a-uuid";

        setAuthentication(
                jwtAuthentication(jwtWithSubject(subject))
        );

        assertThatThrownBy(() -> provider.getCurrentUser())
                .isInstanceOf(CurrentAuthenticatedUserException.class)
                .hasMessage(USER_UNAVAILABLE_MESSAGE)
                .hasCauseInstanceOf(IllegalArgumentException.class)
                .satisfies(throwable -> assertThat(throwable.getMessage())
                .doesNotContain(subject));
    }

    @Test
    void shouldRejectInactiveUserIdWhenRepositoryIsProvided() {

        SpringSecurityCurrentAuthenticatedUserProvider activeUserProvider =
                new SpringSecurityCurrentAuthenticatedUserProvider(
                        new FakeUserRepository(false)
                );
        setAuthentication(
                jwtAuthentication(
                        jwtWithSubject(USER_ID.toString())
                )
        );

        assertUnavailableState(activeUserProvider::getCurrentUser);
    }

    @Test
    void shouldUseSameSafeMessageForAllUnavailableStates() {

        assertUnavailableMessageFor(null);
        assertUnavailableMessageFor(
                UsernamePasswordAuthenticationToken.unauthenticated(
                        "principal",
                        "credentials"
                )
        );
        assertUnavailableMessageFor(
                UsernamePasswordAuthenticationToken.authenticated(
                        "principal",
                        "credentials",
                        List.of(new SimpleGrantedAuthority("ROLE_TEST"))
                )
        );
        assertUnavailableMessageFor(
                jwtAuthentication(jwtWithoutSubject())
        );
        assertUnavailableMessageFor(
                jwtAuthentication(jwtWithSubject("   "))
        );
        assertUnavailableMessageFor(
                jwtAuthentication(jwtWithSubject("not-a-uuid"))
        );
    }

    @Test
    void shouldNotExposeSubjectInFailureMessage() {

        String subject = "not-a-uuid";

        setAuthentication(
                jwtAuthentication(jwtWithSubject(subject))
        );

        assertThatThrownBy(() -> provider.getCurrentUser())
                .isInstanceOf(CurrentAuthenticatedUserException.class)
                .hasMessage(USER_UNAVAILABLE_MESSAGE)
                .satisfies(throwable -> assertThat(throwable.getMessage())
                        .doesNotContain(subject));
    }

    private static Jwt jwtWithSubject(String subject) {
        return Jwt.withTokenValue("access-token")
                .header("alg", "HS256")
                .claim("sub", subject)
                .issuedAt(ISSUED_AT)
                .expiresAt(EXPIRES_AT)
                .build();
    }

    private static Jwt jwtWithoutSubject() {
        return Jwt.withTokenValue("access-token")
                .header("alg", "HS256")
                .issuedAt(ISSUED_AT)
                .expiresAt(EXPIRES_AT)
                .build();
    }

    private static JwtAuthenticationToken jwtAuthentication(Jwt jwt) {
        return new JwtAuthenticationToken(
                jwt,
                List.of(new SimpleGrantedAuthority("SCOPE_test")),
                "test-principal"
        );
    }

    private static void setAuthentication(Authentication authentication) {
        SecurityContext context =
                SecurityContextHolder.createEmptyContext();

        context.setAuthentication(authentication);

        SecurityContextHolder.setContext(context);
    }

    private void assertUnavailableMessageFor(
            Authentication authentication
    ) {
        setAuthentication(authentication);

        assertUnavailableState(() -> provider.getCurrentUser());

        SecurityContextHolder.clearContext();
    }

    private static void assertUnavailableState(ThrowingAction action) {
        assertThatThrownBy(action::run)
                .isInstanceOf(CurrentAuthenticatedUserException.class)
                .hasMessage(USER_UNAVAILABLE_MESSAGE);
    }

    @FunctionalInterface
    private interface ThrowingAction {

        void run();

    }

    private static final class FakeUserRepository
            implements UserRepository {

        private final boolean active;

        private FakeUserRepository(boolean active) {
            this.active = active;
        }

        @Override
        public User save(User user) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<User> findById(UUID id) {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean existsActiveById(UUID id) {
            return active;
        }

        @Override
        public Optional<User> findByGoogleSubject(String googleSubject) {
            throw new UnsupportedOperationException();
        }
    }
}
