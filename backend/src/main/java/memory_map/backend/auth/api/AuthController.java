package memory_map.backend.auth.api;

import jakarta.validation.Valid;
import memory_map.backend.auth.login.GoogleLoginResult;
import memory_map.backend.auth.login.GoogleLoginService;
import memory_map.backend.auth.refresh.RawRefreshToken;
import memory_map.backend.auth.refresh.RefreshTokenLogoutService;
import memory_map.backend.auth.refresh.RefreshTokenRotationResult;
import memory_map.backend.auth.refresh.RefreshTokenRotationService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Clock;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final GoogleLoginService googleLoginService;
    private final RefreshTokenRotationService refreshTokenRotationService;
    private final RefreshTokenLogoutService refreshTokenLogoutService;
    private final Clock clock;

    public AuthController(
            GoogleLoginService googleLoginService,
            RefreshTokenRotationService refreshTokenRotationService,
            RefreshTokenLogoutService refreshTokenLogoutService,
            Clock clock
    ) {
        this.googleLoginService = Objects.requireNonNull(
                googleLoginService,
                "googleLoginService must not be null"
        );
        this.refreshTokenRotationService = Objects.requireNonNull(
                refreshTokenRotationService,
                "refreshTokenRotationService must not be null"
        );
        this.refreshTokenLogoutService = Objects.requireNonNull(
                refreshTokenLogoutService,
                "refreshTokenLogoutService must not be null"
        );
        this.clock = Objects.requireNonNull(
                clock,
                "clock must not be null"
        );
    }

    @PostMapping("/google")
    public ResponseEntity<GoogleLoginResponse> loginWithGoogle(
            @Valid @RequestBody GoogleLoginRequest request
    ) {
        GoogleLoginResult result = googleLoginService.login(
                request.idToken(),
                UUID.randomUUID(),
                UUID.randomUUID(),
                currentTime()
        );

        return ResponseEntity.ok(
                GoogleLoginResponse.from(result)
        );
    }

    @PostMapping("/refresh")
    public ResponseEntity<AuthTokenResponse> refresh(
            @Valid @RequestBody RefreshTokenRequest request
    ) {
        RefreshTokenRotationResult result =
                refreshTokenRotationService.rotate(
                        new RawRefreshToken(request.refreshToken()),
                        UUID.randomUUID(),
                        currentTime()
                );

        return ResponseEntity.ok(
                new AuthTokenResponse(
                        result.accessToken(),
                        result.refreshToken().value()
                )
        );
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(
            @Valid @RequestBody RefreshTokenRequest request
    ) {
        refreshTokenLogoutService.logout(
                new RawRefreshToken(request.refreshToken()),
                currentTime()
        );

        return ResponseEntity.noContent().build();
    }

    private Instant currentTime() {
        return clock.instant();
    }
}
