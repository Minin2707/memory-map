package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.Objects;
import java.util.UUID;

public record DeleteMemoryCommand(

        AuthenticatedUser authenticatedUser,

        UUID memoryId

) {
    public DeleteMemoryCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(memoryId, "memoryId must not be null");
    }

    @Override
    public String toString() {
        return "DeleteMemoryCommand()";
    }
}
