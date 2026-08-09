package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;

public record CreateMemoryCommand(

        AuthenticatedUser authenticatedUser,

        UUID storyId,

        UUID memoryId,

        String title,

        String description,

        String placeName,

        double latitude,

        double longitude,

        LocalDate eventDate,

        Instant currentTime

) {
    private static final int MAX_TITLE_LENGTH = 255;
    private static final int MAX_PLACE_NAME_LENGTH = 255;

    public CreateMemoryCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(storyId, "storyId must not be null");
        Objects.requireNonNull(memoryId, "memoryId must not be null");
        Objects.requireNonNull(title, "title must not be null");
        Objects.requireNonNull(eventDate, "eventDate must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");

        if (title.isBlank()) {
            throw new IllegalArgumentException("title must not be blank");
        }

        if (title.length() > MAX_TITLE_LENGTH) {
            throw new IllegalArgumentException(
                    "title must not exceed 255 characters"
            );
        }

        if (
                placeName != null
                        && placeName.length() > MAX_PLACE_NAME_LENGTH
        ) {
            throw new IllegalArgumentException(
                    "placeName must not exceed 255 characters"
            );
        }

        if (!Double.isFinite(latitude) || latitude < -90.0 || latitude > 90.0) {
            throw new IllegalArgumentException(
                    "latitude must be between -90 and 90"
            );
        }

        if (
                !Double.isFinite(longitude)
                        || longitude < -180.0
                        || longitude > 180.0
        ) {
            throw new IllegalArgumentException(
                    "longitude must be between -180 and 180"
            );
        }
    }

    @Override
    public String toString() {
        return "CreateMemoryCommand["
                + "hasDescription=" + (description != null) + ", "
                + "hasPlaceName=" + (placeName != null)
                + "]";
    }
}
