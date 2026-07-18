package memory_map.backend.user.domain;

import java.time.Instant;
import java.util.UUID;

public record User(

        UUID id,

        String googleSubject,

        String displayName,

        String avatarUrl,

        Instant createdAt,

        Instant updatedAt

) {
}
