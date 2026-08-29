package memory_map.backend.account.api;

import memory_map.backend.account.application.DeleteCurrentAccountCommand;
import memory_map.backend.account.application.DeleteCurrentAccountUseCase;
import memory_map.backend.account.application.UpdateCurrentUserDisplayNameCommand;
import memory_map.backend.account.application.UpdateCurrentUserDisplayNameUseCase;
import memory_map.backend.auth.api.AuthUserResponse;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.user.domain.User;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.time.Clock;
import java.time.Instant;
import java.util.Objects;

@RestController
@RequestMapping("/api/v1/me")
public class AccountController {

    private final DeleteCurrentAccountUseCase deleteCurrentAccountUseCase;
    private final UpdateCurrentUserDisplayNameUseCase
            updateCurrentUserDisplayNameUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;
    private final Clock clock;

    public AccountController(
            DeleteCurrentAccountUseCase deleteCurrentAccountUseCase,
            UpdateCurrentUserDisplayNameUseCase
                    updateCurrentUserDisplayNameUseCase,
            CurrentAuthenticatedUserProvider currentAuthenticatedUserProvider,
            Clock clock
    ) {
        this.deleteCurrentAccountUseCase = Objects.requireNonNull(
                deleteCurrentAccountUseCase,
                "deleteCurrentAccountUseCase must not be null"
        );
        this.updateCurrentUserDisplayNameUseCase = Objects.requireNonNull(
                updateCurrentUserDisplayNameUseCase,
                "updateCurrentUserDisplayNameUseCase must not be null"
        );
        this.currentAuthenticatedUserProvider = Objects.requireNonNull(
                currentAuthenticatedUserProvider,
                "currentAuthenticatedUserProvider must not be null"
        );
        this.clock = Objects.requireNonNull(
                clock,
                "clock must not be null"
        );
    }

    @PatchMapping("/display-name")
    public ResponseEntity<AuthUserResponse> updateDisplayName(
            @Valid @RequestBody UpdateDisplayNameRequest request
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        Instant currentTime = clock.instant();
        User user = updateCurrentUserDisplayNameUseCase.updateDisplayName(
                new UpdateCurrentUserDisplayNameCommand(
                        authenticatedUser,
                        request.displayName(),
                        currentTime
                )
        );

        return ResponseEntity.ok(AuthUserResponse.from(user));
    }

    @DeleteMapping
    public ResponseEntity<Void> deleteCurrentAccount() {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        Instant currentTime = clock.instant();

        deleteCurrentAccountUseCase.deleteCurrentAccount(
                new DeleteCurrentAccountCommand(
                        authenticatedUser,
                        currentTime
                )
        );

        return ResponseEntity.noContent().build();
    }
}
