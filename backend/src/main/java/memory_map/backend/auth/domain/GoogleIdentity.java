package memory_map.backend.auth.domain;

import java.util.Objects;

public record GoogleIdentity(

        String subject,

        String displayName,

        String avatarUrl

) {
    public GoogleIdentity {
        Objects.requireNonNull(subject, "subject must not be null");

        if (subject.isBlank()) {
            throw new IllegalArgumentException("subject must not be blank");
        }
    }
}
