package memory_map.backend.auth.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record RefreshToken(

        UUID id,

        UUID userId,

        UUID familyId,

        String tokenHash,

        Instant createdAt,

        Instant expiresAt,

        Instant consumedAt,

        Instant revokedAt

) {
    public RefreshToken {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(userId, "userId must not be null");
        Objects.requireNonNull(familyId, "familyId must not be null");
        Objects.requireNonNull(tokenHash, "tokenHash must not be null");
        Objects.requireNonNull(createdAt, "createdAt must not be null");
        Objects.requireNonNull(expiresAt, "expiresAt must not be null");

        if (tokenHash.isBlank()) {
            throw new IllegalArgumentException("tokenHash must not be blank");
        }

        if (!expiresAt.isAfter(createdAt)) {
            throw new IllegalArgumentException("expiresAt must be after createdAt");
        }

        if (consumedAt != null && consumedAt.isBefore(createdAt)) {
            throw new IllegalArgumentException("consumedAt must not be before createdAt");
        }

        if (revokedAt != null && revokedAt.isBefore(createdAt)) {
            throw new IllegalArgumentException("revokedAt must not be before createdAt");
        }
    }

    public RefreshToken(
            UUID id,
            UUID userId,
            String tokenHash,
            Instant createdAt,
            Instant expiresAt,
            Instant revokedAt
    ) {
        this(
                id,
                userId,
                id,
                tokenHash,
                createdAt,
                expiresAt,
                null,
                revokedAt
        );
    }
}
