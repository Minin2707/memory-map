package memory_map.backend.auth.api;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import memory_map.backend.IntegrationTest;
import memory_map.backend.auth.domain.GoogleIdentity;
import memory_map.backend.auth.domain.RefreshToken;
import memory_map.backend.auth.google.GoogleIdentityVerificationException;
import memory_map.backend.auth.google.GoogleIdentityVerifier;
import memory_map.backend.auth.refresh.RawRefreshToken;
import memory_map.backend.auth.refresh.RefreshTokenHasher;
import memory_map.backend.auth.repository.RefreshTokenRepository;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@Import(AuthControllerIntegrationTest.AuthControllerIntegrationTestConfiguration.class)
class AuthControllerIntegrationTest extends IntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private FakeGoogleIdentityVerifier googleIdentityVerifier;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private RefreshTokenHasher refreshTokenHasher;

    @Autowired
    private JdbcClient jdbcClient;

    private static final String GOOGLE_ID_TOKEN =
            "raw-google-id-token";
    private static final String GOOGLE_SUBJECT =
            "google-subject-123";
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final String CLEAN_DATABASE_SQL = """
        TRUNCATE TABLE users
        RESTART IDENTITY CASCADE
        """;

    @BeforeEach
    void cleanDatabase() {
        jdbcClient.sql(CLEAN_DATABASE_SQL).update();
        googleIdentityVerifier.identity(
                googleIdentity()
        );
    }

    @Test
    void shouldLoginThroughHttpAndPersistUserAndRefreshToken()
            throws Exception {

        JsonNode response = loginWithGoogle();

        UUID userId = UUID.fromString(
                response.at("/user/id").asText()
        );
        String rawRefreshToken =
                response.at("/refreshToken").asText();
        User persistedUser = userRepository
                .findById(userId)
                .orElseThrow();
        List<RefreshToken> refreshTokens =
                refreshTokenRepository.findByUserId(userId);

        assertThat(response.at("/accessToken").asText()).isNotBlank();
        assertThat(rawRefreshToken).isNotBlank();
        assertThat(persistedUser.googleSubject())
                .isEqualTo(GOOGLE_SUBJECT);
        assertThat(response.at("/user/displayName").asText())
                .isEqualTo(persistedUser.displayName());
        assertThat(response.at("/user/avatarUrl").asText())
                .isEqualTo(persistedUser.avatarUrl());
        assertThat(refreshTokens).hasSize(1);
        assertThat(refreshTokens.getFirst().userId()).isEqualTo(userId);
        assertThat(refreshTokens.getFirst().tokenHash())
                .isEqualTo(refreshTokenHasher.hash(
                        new RawRefreshToken(rawRefreshToken)
                ))
                .isNotEqualTo(rawRefreshToken);

        assertPublicJson(response.toString());
        assertThat(response.toString())
                .doesNotContain(GOOGLE_ID_TOKEN);
    }

    @Test
    void shouldRefreshThroughHttpAndRotatePersistedToken()
            throws Exception {

        JsonNode loginResponse = loginWithGoogle();
        String oldRawRefreshToken =
                loginResponse.at("/refreshToken").asText();
        RefreshToken oldPersistedToken = refreshTokenRepository
                .findByTokenHash(refreshTokenHasher.hash(
                        new RawRefreshToken(oldRawRefreshToken)
                ))
                .orElseThrow();

        JsonNode refreshResponse = postJson(
                "/api/v1/auth/refresh",
                """
                {
                  "refreshToken": "%s"
                }
                """.formatted(oldRawRefreshToken),
                200
        );

        String newRawRefreshToken =
                refreshResponse.at("/refreshToken").asText();
        RefreshToken loadedOldToken = refreshTokenRepository
                .findById(oldPersistedToken.id())
                .orElseThrow();
        RefreshToken newPersistedToken = refreshTokenRepository
                .findByTokenHash(refreshTokenHasher.hash(
                        new RawRefreshToken(newRawRefreshToken)
                ))
                .orElseThrow();

        assertThat(refreshResponse.at("/accessToken").asText())
                .isNotBlank();
        assertThat(newRawRefreshToken)
                .isNotBlank()
                .isNotEqualTo(oldRawRefreshToken);
        assertThat(loadedOldToken.consumedAt()).isEqualTo(CURRENT_TIME);
        assertThat(loadedOldToken.revokedAt()).isNull();
        assertThat(newPersistedToken.familyId())
                .isEqualTo(oldPersistedToken.familyId());
        assertThat(newPersistedToken.userId())
                .isEqualTo(oldPersistedToken.userId());
        assertThat(newPersistedToken.consumedAt()).isNull();
        assertThat(newPersistedToken.revokedAt()).isNull();
        assertThat(newPersistedToken.tokenHash())
                .isNotEqualTo(newRawRefreshToken);
        assertPublicJson(refreshResponse.toString());
    }

    @Test
    void shouldRejectRefreshTokenReuseWithGenericUnauthorizedResponse()
            throws Exception {

        JsonNode loginResponse = loginWithGoogle();
        String oldRawRefreshToken =
                loginResponse.at("/refreshToken").asText();
        JsonNode refreshResponse = postJson(
                "/api/v1/auth/refresh",
                """
                {
                  "refreshToken": "%s"
                }
                """.formatted(oldRawRefreshToken),
                200
        );
        String newRawRefreshToken =
                refreshResponse.at("/refreshToken").asText();

        String response = mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "%s"
                                }
                                """.formatted(oldRawRefreshToken)))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        RefreshToken newPersistedToken = refreshTokenRepository
                .findByTokenHash(refreshTokenHasher.hash(
                        new RawRefreshToken(newRawRefreshToken)
                ))
                .orElseThrow();

        assertThat(response)
                .contains("Authentication failed")
                .doesNotContain("reuse")
                .doesNotContain("family")
                .doesNotContain(oldRawRefreshToken);
        assertThat(newPersistedToken.revokedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldLogoutThroughHttpAndRevokePersistedToken()
            throws Exception {

        JsonNode loginResponse = loginWithGoogle();
        String rawRefreshToken =
                loginResponse.at("/refreshToken").asText();
        RefreshToken persistedToken = refreshTokenRepository
                .findByTokenHash(refreshTokenHasher.hash(
                        new RawRefreshToken(rawRefreshToken)
                ))
                .orElseThrow();

        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "%s"
                                }
                                """.formatted(rawRefreshToken)))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        RefreshToken revokedToken = refreshTokenRepository
                .findById(persistedToken.id())
                .orElseThrow();

        assertThat(revokedToken.revokedAt()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldReturnUnauthorizedForUnknownRefreshToken()
            throws Exception {

        String response = mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "unknown-refresh-token"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .contains("Authentication failed")
                .doesNotContain("unknown-refresh-token")
                .doesNotContain("stackTrace")
                .doesNotContain("cause");
    }

    @Test
    void shouldKeepLogoutIdempotentForUnknownRefreshToken()
            throws Exception {

        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "unknown-refresh-token"
                                }
                                """))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));
    }

    private JsonNode loginWithGoogle() throws Exception {
        return postJson(
                "/api/v1/auth/google",
                """
                {
                  "idToken": "%s"
                }
                """.formatted(GOOGLE_ID_TOKEN),
                200
        );
    }

    private JsonNode postJson(
            String path,
            String request,
            int expectedStatus
    ) throws Exception {
        String response = mockMvc.perform(post(path)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(request))
                .andExpect(status().is(expectedStatus))
                .andReturn()
                .getResponse()
                .getContentAsString();

        return jsonMapper.readTree(response);
    }

    private static void assertPublicJson(String response) {
        assertThat(response)
                .doesNotContain("googleSubject")
                .doesNotContain("familyId")
                .doesNotContain("tokenHash")
                .doesNotContain("consumedAt")
                .doesNotContain("createdAt")
                .doesNotContain("updatedAt")
                .doesNotContain("revokedAt")
                .doesNotContain("expiresAt")
                .doesNotContain("stackTrace")
                .doesNotContain("cause");
    }

    private static GoogleIdentity googleIdentity() {
        return new GoogleIdentity(
                GOOGLE_SUBJECT,
                "Konstantin",
                "https://example.com/avatar.png"
        );
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class AuthControllerIntegrationTestConfiguration {

        @Bean
        @Primary
        Clock fixedClock() {
            return Clock.fixed(
                    CURRENT_TIME,
                    ZoneOffset.UTC
            );
        }

        @Bean
        @Primary
        FakeGoogleIdentityVerifier fakeGoogleIdentityVerifier() {
            return new FakeGoogleIdentityVerifier();
        }
    }

    static final class FakeGoogleIdentityVerifier
            implements GoogleIdentityVerifier {

        private volatile GoogleIdentity identity = googleIdentity();

        @Override
        public GoogleIdentity verify(String idToken) {
            if (!GOOGLE_ID_TOKEN.equals(idToken)) {
                throw new GoogleIdentityVerificationException(
                        "Google ID token verification failed"
                );
            }

            return identity;
        }

        private void identity(GoogleIdentity identity) {
            this.identity = identity;
        }
    }
}
