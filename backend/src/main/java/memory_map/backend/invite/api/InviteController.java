package memory_map.backend.invite.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.invite.application.AcceptInviteCommand;
import memory_map.backend.invite.application.AcceptInviteUseCase;
import memory_map.backend.invite.application.CreateInviteCommand;
import memory_map.backend.invite.application.CreateInviteUseCase;
import memory_map.backend.invite.application.CreatedInvite;
import memory_map.backend.story.api.UserStoryResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Clock;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
public class InviteController {

    private final CreateInviteUseCase createInviteUseCase;
    private final AcceptInviteUseCase acceptInviteUseCase;
    private final CurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;
    private final Clock clock;

    public InviteController(
            CreateInviteUseCase createInviteUseCase,
            AcceptInviteUseCase acceptInviteUseCase,
            CurrentAuthenticatedUserProvider
                    currentAuthenticatedUserProvider,
            Clock clock
    ) {
        this.createInviteUseCase = Objects.requireNonNull(
                createInviteUseCase,
                "createInviteUseCase must not be null"
        );
        this.acceptInviteUseCase = Objects.requireNonNull(
                acceptInviteUseCase,
                "acceptInviteUseCase must not be null"
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

    @PostMapping("/stories/{storyId}/invites")
    public ResponseEntity<CreatedInviteResponse> createInvite(
            @PathVariable UUID storyId
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        UUID inviteId = UUID.randomUUID();
        Instant currentTime = clock.instant();

        CreatedInvite createdInvite = createInviteUseCase.createInvite(
                new CreateInviteCommand(
                        authenticatedUser,
                        storyId,
                        inviteId,
                        currentTime
                )
        );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(CreatedInviteResponse.from(createdInvite));
    }

    @PostMapping("/invites/{token}/accept")
    public UserStoryResponse acceptInvite(
            @PathVariable String token
    ) {
        AuthenticatedUser authenticatedUser =
                currentAuthenticatedUserProvider.getCurrentUser();
        Instant currentTime = clock.instant();

        return UserStoryResponse.from(
                acceptInviteUseCase.acceptInvite(
                        new AcceptInviteCommand(
                                authenticatedUser,
                                token,
                                currentTime
                        )
                )
        );
    }
}
