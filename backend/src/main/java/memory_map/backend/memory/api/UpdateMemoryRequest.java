package memory_map.backend.memory.api;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.memory.application.UpdateMemoryCommand;
import memory_map.backend.story.api.PatchField;
import tools.jackson.databind.annotation.JsonDeserialize;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;

@JsonDeserialize(using = UpdateMemoryRequestDeserializer.class)
public record UpdateMemoryRequest(

        PatchField<String> title,

        PatchField<String> description,

        PatchField<String> placeName,

        PatchField<Double> latitude,

        PatchField<Double> longitude,

        PatchField<LocalDate> eventDate

) {
    private static final int MAX_TITLE_LENGTH = 255;
    private static final int MAX_PLACE_NAME_LENGTH = 255;

    public UpdateMemoryRequest {
        Objects.requireNonNull(title, "title must not be null");
        Objects.requireNonNull(
                description,
                "description must not be null"
        );
        Objects.requireNonNull(placeName, "placeName must not be null");
        Objects.requireNonNull(latitude, "latitude must not be null");
        Objects.requireNonNull(longitude, "longitude must not be null");
        Objects.requireNonNull(eventDate, "eventDate must not be null");

        if (!hasAnyPresentField(
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

    public UpdateMemoryCommand toCommand(
            AuthenticatedUser authenticatedUser,
            UUID memoryId,
            Instant currentTime
    ) {
        return new UpdateMemoryCommand(
                authenticatedUser,
                memoryId,
                toApplicationField(title),
                toApplicationField(description),
                toApplicationField(placeName),
                toApplicationField(latitude),
                toApplicationField(longitude),
                toApplicationField(eventDate),
                currentTime
        );
    }

    @Override
    public String toString() {
        return "UpdateMemoryRequest["
                + "updatesTitle=" + title.isPresent() + ", "
                + "updatesDescription=" + description.isPresent() + ", "
                + "updatesPlaceName=" + placeName.isPresent() + ", "
                + "updatesLocation=" + updatesLocation() + ", "
                + "updatesEventDate=" + eventDate.isPresent()
                + "]";
    }

    private boolean updatesLocation() {
        return latitude.isPresent() || longitude.isPresent();
    }

    private static boolean hasAnyPresentField(
            PatchField<?> title,
            PatchField<?> description,
            PatchField<?> placeName,
            PatchField<?> latitude,
            PatchField<?> longitude,
            PatchField<?> eventDate
    ) {
        return title.isPresent()
                || description.isPresent()
                || placeName.isPresent()
                || latitude.isPresent()
                || longitude.isPresent()
                || eventDate.isPresent();
    }

    private static void validateTitle(PatchField<String> title) {
        if (!title.isPresent()) {
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
        if (!placeName.isPresent() || placeName.value() == null) {
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
        if (latitude.isPresent() != longitude.isPresent()) {
            throw new IllegalArgumentException(
                    "latitude and longitude must be provided together"
            );
        }

        if (!latitude.isPresent()) {
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
        if (!eventDate.isPresent()) {
            return;
        }

        Objects.requireNonNull(
                eventDate.value(),
                "eventDate value must not be null"
        );
    }

    private static <T> memory_map.backend.memory.application.PatchField<T>
    toApplicationField(PatchField<T> field) {
        if (field.isPresent()) {
            return memory_map.backend.memory.application.PatchField
                    .provided(field.value());
        }

        return memory_map.backend.memory.application.PatchField
                .notProvided();
    }
}
