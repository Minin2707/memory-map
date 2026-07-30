package memory_map.backend.auth.api;

import memory_map.backend.auth.login.GoogleLoginResult;
import memory_map.backend.auth.login.GoogleLoginService;
import memory_map.backend.auth.refresh.RawRefreshToken;
import memory_map.backend.auth.refresh.RefreshTokenLogoutService;
import memory_map.backend.auth.refresh.RefreshTokenRotationResult;
import memory_map.backend.auth.refresh.RefreshTokenRotationService;
import memory_map.backend.user.domain.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(AuthController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import({
        AuthApiExceptionHandler.class,
        AuthControllerTest.AuthControllerTestConfiguration.class
})
class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeGoogleLoginService googleLoginService;

    @Autowired
    private FakeRefreshTokenRotationService refreshTokenRotationService;

    @Autowired
    private FakeRefreshTokenLogoutService refreshTokenLogoutService;

    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldLoginWithGoogle() throws Exception {

        String response = mockMvc.perform(post("/api/v1/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idToken": "raw-google-id-token"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.id")
                        .value("00000000-0000-0000-0000-000000000001"))
                .andExpect(jsonPath("$.user.displayName")
                        .value("Memory Map User"))
                .andExpect(jsonPath("$.user.avatarUrl").value((Object) null))
                .andExpect(jsonPath("$.accessToken")
                        .value("issued-access-token"))
                .andExpect(jsonPath("$.refreshToken")
                        .value("issued-refresh-token"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(googleLoginService.receivedGoogleIdToken())
                .isEqualTo("raw-google-id-token");
        assertThat(googleLoginService.receivedNewUserId()).isNotNull();
        assertThat(googleLoginService.receivedNewRefreshTokenId())
                .isNotNull()
                .isNotEqualTo(googleLoginService.receivedNewUserId());
        assertThat(googleLoginService.receivedCurrentTime())
                .isEqualTo(CURRENT_TIME);
        assertThat(response)
                .doesNotContain("googleSubject")
                .doesNotContain("tokenHash")
                .doesNotContain("createdAt")
                .doesNotContain("updatedAt")
                .doesNotContain("raw-google-id-token");
    }

    @Test
    void shouldReturnBadRequestForBlankGoogleIdToken()
            throws Exception {

        mockMvc.perform(post("/api/v1/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idToken": "   "
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void shouldRefreshTokens() throws Exception {

        String response = mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "current-refresh-token"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken")
                        .value("rotated-access-token"))
                .andExpect(jsonPath("$.refreshToken")
                        .value("rotated-refresh-token"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(refreshTokenRotationService.receivedRawToken())
                .isEqualTo(new RawRefreshToken("current-refresh-token"));
        assertThat(refreshTokenRotationService.receivedNewRefreshTokenId())
                .isNotNull();
        assertThat(refreshTokenRotationService.receivedCurrentTime())
                .isEqualTo(CURRENT_TIME);
        assertThat(response)
                .doesNotContain("tokenHash")
                .doesNotContain("expiresAt")
                .doesNotContain("revokedAt");
    }

    @Test
    void shouldReturnBadRequestForBlankRefreshToken()
            throws Exception {

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "   "
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void shouldLogout() throws Exception {

        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "current-refresh-token"
                                }
                                """))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        assertThat(refreshTokenLogoutService.receivedRawToken())
                .isEqualTo(new RawRefreshToken("current-refresh-token"));
        assertThat(refreshTokenLogoutService.receivedCurrentTime())
                .isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldReturnNoContentForLogout() throws Exception {

        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "current-refresh-token"
                                }
                                """))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class AuthControllerTestConfiguration {

        @Bean
        Clock clock() {
            return Clock.fixed(
                    CURRENT_TIME,
                    ZoneOffset.UTC
            );
        }

        @Bean
        FakeGoogleLoginService googleLoginService() {
            return new FakeGoogleLoginService();
        }

        @Bean
        FakeRefreshTokenRotationService refreshTokenRotationService() {
            return new FakeRefreshTokenRotationService();
        }

        @Bean
        FakeRefreshTokenLogoutService refreshTokenLogoutService() {
            return new FakeRefreshTokenLogoutService();
        }
    }

    static final class FakeGoogleLoginService
            implements GoogleLoginService {

        private String receivedGoogleIdToken;
        private UUID receivedNewUserId;
        private UUID receivedNewRefreshTokenId;
        private Instant receivedCurrentTime;

        @Override
        public GoogleLoginResult login(
                String googleIdToken,
                UUID newUserId,
                UUID newRefreshTokenId,
                Instant currentTime
        ) {
            receivedGoogleIdToken = googleIdToken;
            receivedNewUserId = newUserId;
            receivedNewRefreshTokenId = newRefreshTokenId;
            receivedCurrentTime = currentTime;

            return new GoogleLoginResult(
                    new User(
                            UUID.fromString(
                                    "00000000-0000-0000-0000-000000000001"
                            ),
                            "google-subject-123",
                            "Memory Map User",
                            null,
                            CURRENT_TIME,
                            CURRENT_TIME
                    ),
                    "issued-access-token",
                    new RawRefreshToken("issued-refresh-token")
            );
        }

        private String receivedGoogleIdToken() {
            return receivedGoogleIdToken;
        }

        private UUID receivedNewUserId() {
            return receivedNewUserId;
        }

        private UUID receivedNewRefreshTokenId() {
            return receivedNewRefreshTokenId;
        }

        private Instant receivedCurrentTime() {
            return receivedCurrentTime;
        }
    }

    static final class FakeRefreshTokenRotationService
            implements RefreshTokenRotationService {

        private RawRefreshToken receivedRawToken;
        private UUID receivedNewRefreshTokenId;
        private Instant receivedCurrentTime;

        @Override
        public RefreshTokenRotationResult rotate(
                RawRefreshToken currentRefreshToken,
                UUID newRefreshTokenId,
                Instant currentTime
        ) {
            receivedRawToken = currentRefreshToken;
            receivedNewRefreshTokenId = newRefreshTokenId;
            receivedCurrentTime = currentTime;

            return new RefreshTokenRotationResult(
                    "rotated-access-token",
                    new RawRefreshToken("rotated-refresh-token")
            );
        }

        private RawRefreshToken receivedRawToken() {
            return receivedRawToken;
        }

        private UUID receivedNewRefreshTokenId() {
            return receivedNewRefreshTokenId;
        }

        private Instant receivedCurrentTime() {
            return receivedCurrentTime;
        }
    }

    static final class FakeRefreshTokenLogoutService
            implements RefreshTokenLogoutService {

        private RawRefreshToken receivedRawToken;
        private Instant receivedCurrentTime;

        @Override
        public void logout(
                RawRefreshToken refreshToken,
                Instant currentTime
        ) {
            receivedRawToken = refreshToken;
            receivedCurrentTime = currentTime;
        }

        private RawRefreshToken receivedRawToken() {
            return receivedRawToken;
        }

        private Instant receivedCurrentTime() {
            return receivedCurrentTime;
        }
    }
}
