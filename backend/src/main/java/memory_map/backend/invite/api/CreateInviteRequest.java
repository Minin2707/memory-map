package memory_map.backend.invite.api;

import jakarta.validation.constraints.NotNull;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.invite.application.CreateInviteCommand;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record CreateInviteRequest(

        @NotNull
        InviteTargetRole role

) {
    public CreateInviteRequest {
        Objects.requireNonNull(role, "role must not be null");
    }

    public CreateInviteCommand toCommand(
            AuthenticatedUser authenticatedUser,
            UUID storyId,
            UUID inviteId,
            Instant currentTime
    ) {
        return new CreateInviteCommand(
                authenticatedUser,
                storyId,
                inviteId,
                role.toStoryRole(),
                currentTime
        );
    }
}
