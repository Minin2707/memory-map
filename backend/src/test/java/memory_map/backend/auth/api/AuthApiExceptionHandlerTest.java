package memory_map.backend.auth.api;

import memory_map.backend.auth.google.GoogleIdentityVerificationException;
import memory_map.backend.auth.login.GoogleLoginResult;
import memory_map.backend.auth.login.GoogleLoginService;
import memory_map.backend.auth.refresh.InvalidRefreshTokenException;
import memory_map.backend.auth.refresh.RawRefreshToken;
import memory_map.backend.auth.refresh.RefreshTokenLogoutService;
import memory_map.backend.auth.refresh.RefreshTokenRotationResult;
import memory_map.backend.auth.refresh.RefreshTokenRotationService;
import org.junit.jupiter.api.BeforeEach;
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
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(AuthController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import({
        AuthApiExceptionHandler.class,
        AuthApiExceptionHandlerTest.AuthApiExceptionHandlerTestConfiguration.class
})
class AuthApiExceptionHandlerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeGoogleLoginService googleLoginService;

    @Autowired
    private FakeRefreshTokenRotationService refreshTokenRotationService;

    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @BeforeEach
    void resetFakes() {
        googleLoginService.reset();
        refreshTokenRotationService.reset();
    }

    @Test
    void shouldReturnUnauthorizedForGoogleVerificationFailure()
            throws Exception {

        googleLoginService.failWith(
                new GoogleIdentityVerificationException(
                        "raw-google-id-token was rejected"
                )
        );

        mockMvc.perform(post("/api/v1/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idToken": "raw-google-id-token"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.title").value("Unauthorized"))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.detail")
                        .value("Authentication failed"));
    }

    @Test
    void shouldReturnUnauthorizedForInvalidRefreshTokenDuringRotation()
            throws Exception {

        refreshTokenRotationService.failWith(
                new InvalidRefreshTokenException(
                        "raw-refresh-token was rejected"
                )
        );

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "raw-refresh-token"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.title").value("Unauthorized"))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.detail")
                        .value("Authentication failed"));
    }

    @Test
    void shouldUseSameSafeBodyForGoogleAndRefreshFailures()
            throws Exception {

        googleLoginService.failWith(
                new GoogleIdentityVerificationException(
                        "google-specific failure"
                )
        );
        refreshTokenRotationService.failWith(
                new InvalidRefreshTokenException(
                        "refresh-specific failure"
                )
        );

        String googleResponse = mockMvc.perform(post("/api/v1/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idToken": "raw-google-id-token"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String refreshResponse = mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "raw-refresh-token"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(googleResponse)
                .contains("\"title\":\"Unauthorized\"")
                .contains("\"status\":401")
                .contains("\"detail\":\"Authentication failed\"");
        assertThat(refreshResponse)
                .contains("\"title\":\"Unauthorized\"")
                .contains("\"status\":401")
                .contains("\"detail\":\"Authentication failed\"");
    }

    @Test
    void shouldNotExposeExceptionMessage() throws Exception {

        refreshTokenRotationService.failWith(
                new InvalidRefreshTokenException(
                        "database token state is invalid"
                )
        );

        String response = mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "raw-refresh-token"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain("database token state is invalid")
                .doesNotContain("InvalidRefreshTokenException")
                .doesNotContain("stackTrace")
                .doesNotContain("cause");
    }

    @Test
    void shouldNotExposeRawToken() throws Exception {

        refreshTokenRotationService.failWith(
                new InvalidRefreshTokenException(
                        "raw-refresh-token"
                )
        );

        String response = mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "raw-refresh-token"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat(response)
                .doesNotContain("raw-refresh-token")
                .doesNotContain("tokenHash");
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class AuthApiExceptionHandlerTestConfiguration {

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
        RefreshTokenLogoutService refreshTokenLogoutService() {
            return (refreshToken, currentTime) -> {
            };
        }
    }

    static final class FakeGoogleLoginService
            implements GoogleLoginService {

        private RuntimeException exception;

        @Override
        public GoogleLoginResult login(
                String googleIdToken,
                UUID newUserId,
                UUID newRefreshTokenId,
                Instant currentTime
        ) {
            if (exception != null) {
                throw exception;
            }

            throw new UnsupportedOperationException();
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            exception = null;
        }
    }

    static final class FakeRefreshTokenRotationService
            implements RefreshTokenRotationService {

        private RuntimeException exception;

        @Override
        public RefreshTokenRotationResult rotate(
                RawRefreshToken currentRefreshToken,
                UUID newRefreshTokenId,
                Instant currentTime
        ) {
            if (exception != null) {
                throw exception;
            }

            throw new UnsupportedOperationException();
        }

        private void failWith(RuntimeException exception) {
            this.exception = exception;
        }

        private void reset() {
            exception = null;
        }
    }
}
