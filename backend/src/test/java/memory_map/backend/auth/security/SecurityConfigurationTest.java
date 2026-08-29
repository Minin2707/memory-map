package memory_map.backend.auth.security;

import memory_map.backend.auth.api.AuthApiExceptionHandler;
import memory_map.backend.auth.api.AuthController;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.jwt.AccessTokenService;
import memory_map.backend.auth.jwt.JwtAccessTokenConfiguration;
import memory_map.backend.auth.jwt.JwtAuthProperties;
import memory_map.backend.auth.login.GoogleLoginResult;
import memory_map.backend.auth.login.GoogleLoginService;
import memory_map.backend.auth.refresh.RawRefreshToken;
import memory_map.backend.auth.refresh.RefreshTokenLogoutService;
import memory_map.backend.auth.refresh.RefreshTokenRotationResult;
import memory_map.backend.auth.refresh.RefreshTokenRotationService;
import memory_map.backend.common.config.ClockConfig;
import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringBootConfiguration;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(classes = SecurityConfigurationTest.TestApplication.class)
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SecurityConfigurationTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final String PROTECTED_ENDPOINT =
            "/api/v1/security-test/protected";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private AccessTokenService accessTokenService;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private JwtAuthProperties jwtAuthProperties;

    @Autowired
    private Clock clock;

    @Autowired
    private CurrentAuthenticatedUserProvider currentAuthenticatedUserProvider;

    @Test
    void shouldAllowGoogleLoginWithoutAuthentication() throws Exception {

        mockMvc.perform(post("/api/v1/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idToken": "raw-google-id-token"
                                }
                                """))
                .andExpect(status().isOk());
    }

    @Test
    void shouldAllowRefreshWithoutAuthentication() throws Exception {

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "current-refresh-token"
                                }
                                """))
                .andExpect(status().isOk());
    }

    @Test
    void shouldAllowLogoutWithoutAuthentication() throws Exception {

        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "current-refresh-token"
                                }
                                """))
                .andExpect(status().isNoContent());
    }

    @Test
    void shouldRejectProtectedEndpointWithoutBearerToken() throws Exception {

        mockMvc.perform(get(PROTECTED_ENDPOINT))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldRejectAvatarEndpointWithoutBearerToken() throws Exception {

        mockMvc.perform(get("/api/v1/me/avatar"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldRejectDisplayNameEndpointWithoutBearerToken() throws Exception {

        mockMvc.perform(patch("/api/v1/me/display-name")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "displayName": "Anna"
                                }
                                """))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldRejectProtectedEndpointWithMalformedBearerToken()
            throws Exception {

        String malformedToken = "not-a-jwt";

        String response = mockMvc.perform(get(PROTECTED_ENDPOINT)
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + malformedToken
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response).doesNotContain(malformedToken);
    }

    @Test
    void shouldRejectProtectedEndpointWithInvalidSignature()
            throws Exception {

        String token = tamperSignature(validAccessToken());

        String response = mockMvc.perform(get(PROTECTED_ENDPOINT)
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + token
                        ))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response).doesNotContain(token);
    }

    @Test
    void shouldRejectProtectedEndpointWithExpiredToken()
            throws Exception {

        mockMvc.perform(get(PROTECTED_ENDPOINT)
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + expiredAccessToken()
                        ))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void shouldAllowProtectedEndpointWithValidAccessToken()
            throws Exception {

        String token = validAccessToken();

        String response = mockMvc.perform(get(PROTECTED_ENDPOINT)
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + token
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(USER_ID.toString()))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain(token)
                .doesNotContain("google-subject-123")
                .doesNotContain("subject")
                .doesNotContain("iss")
                .doesNotContain("exp")
                .doesNotContain("iat");
    }

    @Test
    void shouldKeepDefaultContentTypeProtectionHeaderEnabled()
            throws Exception {

        mockMvc.perform(get(PROTECTED_ENDPOINT)
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken()
                        ))
                .andExpect(status().isOk())
                .andExpect(header().string(
                        "X-Content-Type-Options",
                        "nosniff"
                ));
    }

    @Test
    void shouldWriteHstsForSecureRequestsOnly() throws Exception {

        mockMvc.perform(get(PROTECTED_ENDPOINT)
                        .secure(true)
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken()
                        ))
                .andExpect(status().isOk())
                .andExpect(header().string(
                        "Strict-Transport-Security",
                        "max-age=31536000"
                ));
    }

    @Test
    void shouldNotWriteHstsForLocalHttpRequests() throws Exception {

        mockMvc.perform(get(PROTECTED_ENDPOINT)
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken()
                        ))
                .andExpect(status().isOk())
                .andExpect(header().doesNotExist(
                        "Strict-Transport-Security"
                ));
    }

    @Test
    void shouldExposeInternalUserIdAsJwtSubject() throws Exception {

        mockMvc.perform(get(PROTECTED_ENDPOINT)
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken()
                        ))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(USER_ID.toString()));
    }

    @Test
    void shouldCreateCurrentAuthenticatedUserProviderBean() {

        assertThat(currentAuthenticatedUserProvider)
                .isInstanceOf(
                        SpringSecurityCurrentAuthenticatedUserProvider.class
                );
    }

    @Test
    void shouldNotCreateHttpSession() throws Exception {

        MvcResult result = mockMvc.perform(get(PROTECTED_ENDPOINT)
                        .header(
                                HttpHeaders.AUTHORIZATION,
                                "Bearer " + validAccessToken()
                        ))
                .andExpect(status().isOk())
                .andReturn();

        assertThat(result.getRequest().getSession(false)).isNull();
    }

    private String validAccessToken() {
        return accessTokenService.issueAccessToken(
                USER_ID,
                clock.instant()
        );
    }

    private String expiredAccessToken() {
        Instant issuedAt = clock.instant().minus(Duration.ofHours(2));
        Instant expiresAt = clock.instant().minus(Duration.ofHours(1));

        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(jwtAuthProperties.issuer())
                .subject(USER_ID.toString())
                .issuedAt(issuedAt)
                .expiresAt(expiresAt)
                .build();

        JwsHeader header = JwsHeader
                .with(MacAlgorithm.HS256)
                .build();

        return jwtEncoder
                .encode(JwtEncoderParameters.from(header, claims))
                .getTokenValue();
    }

    private static String tamperSignature(String token) {
        int signatureStart = token.lastIndexOf('.') + 1;
        char replacement = token.charAt(signatureStart) == 'a'
                ? 'b'
                : 'a';

        return token.substring(0, signatureStart)
                + replacement
                + token.substring(signatureStart + 1);
    }

    @SpringBootConfiguration
    @EnableAutoConfiguration
    @Import({
            AuthApiExceptionHandler.class,
            AuthController.class,
            ClockConfig.class,
            JwtAccessTokenConfiguration.class,
            SecurityConfiguration.class,
            SecurityConfigurationTestConfiguration.class
    })
    static class TestApplication {
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class SecurityConfigurationTestConfiguration {

        @Bean
        GoogleLoginService googleLoginService() {
            return (googleIdToken, newUserId, newRefreshTokenId,
                    currentTime) -> new GoogleLoginResult(
                            new User(
                                    USER_ID,
                                    "google-subject-123",
                                    "Memory Map User",
                                    null,
                                    currentTime,
                                    currentTime
                            ),
                            "issued-access-token",
                            new RawRefreshToken("issued-refresh-token")
                    );
        }

        @Bean
        RefreshTokenRotationService refreshTokenRotationService() {
            return (currentRefreshToken, newRefreshTokenId, currentTime) ->
                    new RefreshTokenRotationResult(
                            "rotated-access-token",
                            new RawRefreshToken("rotated-refresh-token")
                    );
        }

        @Bean
        RefreshTokenLogoutService refreshTokenLogoutService() {
            return (refreshToken, currentTime) -> {
            };
        }

        @Bean
        UserRepository userRepository() {
            return new UserRepository() {

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
                    return true;
                }

                @Override
                public Optional<User> findByGoogleSubject(
                        String googleSubject
                ) {
                    throw new UnsupportedOperationException();
                }
            };
        }

        @Bean
        ProtectedEndpointController protectedEndpointController(
                CurrentAuthenticatedUserProvider
                        currentAuthenticatedUserProvider
        ) {
            return new ProtectedEndpointController(
                    currentAuthenticatedUserProvider
            );
        }
    }

    @RestController
    static class ProtectedEndpointController {

        private final CurrentAuthenticatedUserProvider
                currentAuthenticatedUserProvider;

        ProtectedEndpointController(
                CurrentAuthenticatedUserProvider
                        currentAuthenticatedUserProvider
        ) {
            this.currentAuthenticatedUserProvider =
                    currentAuthenticatedUserProvider;
        }

        @GetMapping(PROTECTED_ENDPOINT)
        Map<String, String> protectedEndpoint() {
            AuthenticatedUser authenticatedUser =
                    currentAuthenticatedUserProvider
                            .getCurrentUser();

            return Map.of(
                    "userId",
                    authenticatedUser.userId().toString()
            );
        }
    }
}
