package memory_map.backend.invite.api;

import memory_map.backend.invite.application.CreatedInvite;

import java.time.Instant;
import java.util.Objects;

public record CreatedInviteResponse(

        String inviteLink,

        Instant expiresAt

) {
    public static CreatedInviteResponse from(CreatedInvite createdInvite) {
        Objects.requireNonNull(
                createdInvite,
                "createdInvite must not be null"
        );

        return new CreatedInviteResponse(
                createdInvite.inviteLink().toString(),
                createdInvite.expiresAt()
        );
    }
}
