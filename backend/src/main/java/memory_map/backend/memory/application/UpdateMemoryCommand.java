package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;

public record UpdateMemoryCommand(

        AuthenticatedUser authenticatedUser,

        UUID memoryId,

        PatchField<String> title,

        PatchField<String> description,

        PatchField<String> placeName,

        PatchField<Double> latitude,

        PatchField<Double> longitude,

        PatchField<LocalDate> eventDate,

        Instant currentTime

) {
    private static final int MAX_TITLE_LENGTH = 255;
    private static final int MAX_PLACE_NAME_LENGTH = 255;

    public UpdateMemoryCommand {
        Objects.requireNonNull(
                authenticatedUser,
                "authenticatedUser must not be null"
        );
        Objects.requireNonNull(memoryId, "memoryId must not be null");
        Objects.requireNonNull(title, "title must not be null");
        Objects.requireNonNull(
                description,
                "description must not be null"
        );
        Objects.requireNonNull(placeName, "placeName must not be null");
        Objects.requireNonNull(latitude, "latitude must not be null");
        Objects.requireNonNull(longitude, "longitude must not be null");
        Objects.requireNonNull(eventDate, "eventDate must not be null");
        Objects.requireNonNull(currentTime, "currentTime must not be null");

        if (!hasAnyProvidedField(
                title,
                description,
                placeName,
                latitude,
                longitude,
                eventDate
        )) {
            throw new IllegalArgumentException(
                    "at least one update field must be provided"
            );
        }

        validateTitle(title);
        validatePlaceName(placeName);
        validateLocation(latitude, longitude);
        validateEventDate(eventDate);
    }

    @Override
    public String toString() {
        return "UpdateMemoryCommand["
                + "updatesTitle=" + title.isProvided() + ", "
                + "updatesDescription=" + description.isProvided() + ", "
                + "updatesPlaceName=" + placeName.isProvided() + ", "
                + "updatesLocation=" + updatesLocation() + ", "
                + "updatesEventDate=" + eventDate.isProvided()
                + "]";
    }

    private boolean updatesLocation() {
        return latitude.isProvided() || longitude.isProvided();
    }

    private static boolean hasAnyProvidedField(
            PatchField<?> title,
            PatchField<?> description,
            PatchField<?> placeName,
            PatchField<?> latitude,
            PatchField<?> longitude,
            PatchField<?> eventDate
    ) {
        return title.isProvided()
                || description.isProvided()
                || placeName.isProvided()
                || latitude.isProvided()
                || longitude.isProvided()
                || eventDate.isProvided();
    }

    private static void validateTitle(PatchField<String> title) {
        if (!title.isProvided()) {
            return;
        }

        Objects.requireNonNull(
                title.value(),
                "title value must not be null"
        );

        if (title.value().isBlank()) {
            throw new IllegalArgumentException(
                    "title value must not be blank"
            );
        }

        if (title.value().length() > MAX_TITLE_LENGTH) {
            throw new IllegalArgumentException(
                    "title value must not exceed 255 characters"
            );
        }
    }

    private static void validatePlaceName(PatchField<String> placeName) {
        if (!placeName.isProvided() || placeName.value() == null) {
            return;
        }

        if (placeName.value().length() > MAX_PLACE_NAME_LENGTH) {
            throw new IllegalArgumentException(
                    "placeName value must not exceed 255 characters"
            );
        }
    }

    private static void validateLocation(
            PatchField<Double> latitude,
            PatchField<Double> longitude
    ) {
        if (latitude.isProvided() != longitude.isProvided()) {
            throw new IllegalArgumentException(
                    "latitude and longitude must be provided together"
            );
        }

        if (!latitude.isProvided()) {
            return;
        }

        Double latitudeValue = Objects.requireNonNull(
                latitude.value(),
                "latitude value must not be null"
        );
        Double longitudeValue = Objects.requireNonNull(
                longitude.value(),
                "longitude value must not be null"
        );

        if (
                !Double.isFinite(latitudeValue)
                        || latitudeValue < -90.0
                        || latitudeValue > 90.0
        ) {
            throw new IllegalArgumentException(
                    "latitude value must be between -90 and 90"
            );
        }

        if (
                !Double.isFinite(longitudeValue)
                        || longitudeValue < -180.0
                        || longitudeValue > 180.0
        ) {
            throw new IllegalArgumentException(
                    "longitude value must be between -180 and 180"
            );
        }
    }

    private static void validateEventDate(PatchField<LocalDate> eventDate) {
        if (!eventDate.isProvided()) {
            return;
        }

        Objects.requireNonNull(
                eventDate.value(),
                "eventDate value must not be null"
        );
    }
}
