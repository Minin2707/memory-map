package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import java.lang.reflect.RecordComponent;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UpdateMemoryCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000021");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00.123456Z");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2024, 5, 18);

    @Test
    void shouldCreateCommandWhenTitleIsProvided() {

        UpdateMemoryCommand command = command(
                PatchField.provided("Updated memory"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        );

        assertThat(command.authenticatedUser())
                .isEqualTo(AUTHENTICATED_USER);
        assertThat(command.memoryId()).isEqualTo(MEMORY_ID);
        assertThat(command.title().value()).isEqualTo("Updated memory");
        assertThat(command.description().isProvided()).isFalse();
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldAllowDescriptionSetAndClear() {

        UpdateMemoryCommand set = command(
                notProvided(),
                PatchField.provided("Updated description"),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        );
        UpdateMemoryCommand clear = command(
                notProvided(),
                PatchField.provided(null),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        );

        assertThat(set.description().value())
                .isEqualTo("Updated description");
        assertThat(clear.description().isProvided()).isTrue();
        assertThat(clear.description().value()).isNull();
    }

    @Test
    void shouldAllowPlaceNameSetAndClear() {

        UpdateMemoryCommand set = command(
                notProvided(),
                notProvided(),
                PatchField.provided("Tbilisi"),
                notProvided(),
                notProvided(),
                notProvided()
        );
        UpdateMemoryCommand clear = command(
                notProvided(),
                notProvided(),
                PatchField.provided(null),
                notProvided(),
                notProvided(),
                notProvided()
        );

        assertThat(set.placeName().value()).isEqualTo("Tbilisi");
        assertThat(clear.placeName().isProvided()).isTrue();
        assertThat(clear.placeName().value()).isNull();
    }

    @Test
    void shouldAllowFullLocationPatch() {

        UpdateMemoryCommand command = command(
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(41.715137),
                PatchField.provided(44.827096),
                notProvided()
        );

        assertThat(command.latitude().value()).isEqualTo(41.715137);
        assertThat(command.longitude().value()).isEqualTo(44.827096);
    }

    @Test
    void shouldAllowEventDatePatch() {

        UpdateMemoryCommand command = command(
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(EVENT_DATE)
        );

        assertThat(command.eventDate().value()).isEqualTo(EVENT_DATE);
    }

    @Test
    void shouldAllowAllFields() {

        UpdateMemoryCommand command = command(
                PatchField.provided("Updated memory"),
                PatchField.provided("Updated description"),
                PatchField.provided("Tbilisi"),
                PatchField.provided(41.715137),
                PatchField.provided(44.827096),
                PatchField.provided(EVENT_DATE)
        );

        assertThat(command.title().value()).isEqualTo("Updated memory");
        assertThat(command.description().value())
                .isEqualTo("Updated description");
        assertThat(command.placeName().value()).isEqualTo("Tbilisi");
        assertThat(command.latitude().value()).isEqualTo(41.715137);
        assertThat(command.longitude().value()).isEqualTo(44.827096);
        assertThat(command.eventDate().value()).isEqualTo(EVENT_DATE);
    }

    @Test
    void shouldAllowOptionalEmptyStrings() {

        UpdateMemoryCommand command = command(
                notProvided(),
                PatchField.provided(""),
                PatchField.provided(""),
                notProvided(),
                notProvided(),
                notProvided()
        );

        assertThat(command.description().value()).isEmpty();
        assertThat(command.placeName().value()).isEmpty();
    }

    @Test
    void shouldAllowLongDescription() {

        String description = "d".repeat(1_000);

        UpdateMemoryCommand command = command(
                notProvided(),
                PatchField.provided(description),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        );

        assertThat(command.description().value()).isEqualTo(description);
    }

    @Test
    void shouldAllowExactMaxLengths() {

        String title = "a".repeat(255);
        String placeName = "b".repeat(255);

        UpdateMemoryCommand command = command(
                PatchField.provided(title),
                notProvided(),
                PatchField.provided(placeName),
                notProvided(),
                notProvided(),
                notProvided()
        );

        assertThat(command.title().value()).hasSize(255);
        assertThat(command.placeName().value()).hasSize(255);
    }

    @Test
    void shouldAllowCoordinateBoundaries() {

        UpdateMemoryCommand min = command(
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(-90.0),
                PatchField.provided(-180.0),
                notProvided()
        );
        UpdateMemoryCommand max = command(
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(90.0),
                PatchField.provided(180.0),
                notProvided()
        );

        assertThat(min.latitude().value()).isEqualTo(-90.0);
        assertThat(min.longitude().value()).isEqualTo(-180.0);
        assertThat(max.latitude().value()).isEqualTo(90.0);
        assertThat(max.longitude().value()).isEqualTo(180.0);
    }

    @Test
    void shouldAllowFutureEventDate() {

        LocalDate futureDate = LocalDate.of(2027, 2, 14);

        UpdateMemoryCommand command = command(
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(futureDate)
        );

        assertThat(command.eventDate().value()).isEqualTo(futureDate);
    }

    @Test
    void shouldPreserveValuesWithoutNormalization() {

        UpdateMemoryCommand command = command(
                PatchField.provided("  Updated memory  "),
                PatchField.provided("  Updated description  "),
                PatchField.provided("  Tbilisi  "),
                PatchField.provided(-0.0),
                PatchField.provided(0.0),
                notProvided()
        );

        assertThat(command.title().value())
                .isEqualTo("  Updated memory  ");
        assertThat(command.description().value())
                .isEqualTo("  Updated description  ");
        assertThat(command.placeName().value()).isEqualTo("  Tbilisi  ");
        assertThat(command.latitude().value()).isEqualTo(-0.0);
        assertThat(command.longitude().value()).isEqualTo(0.0);
    }

    @Test
    void shouldRejectNullRequiredInputs() {

        assertThatThrownBy(() -> new UpdateMemoryCommand(
                null,
                MEMORY_ID,
                title(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
        assertThatThrownBy(() -> new UpdateMemoryCommand(
                AUTHENTICATED_USER,
                null,
                title(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memoryId must not be null");
        assertThatThrownBy(() -> commandWithCurrentTime(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldRejectNullPatchFieldWrappers() {

        assertNullPatchFieldRejected("title");
        assertNullPatchFieldRejected("description");
        assertNullPatchFieldRejected("placeName");
        assertNullPatchFieldRejected("latitude");
        assertNullPatchFieldRejected("longitude");
        assertNullPatchFieldRejected("eventDate");
    }

    @Test
    void shouldRejectEmptyPatch() {

        assertThatThrownBy(() -> command(
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("at least one update field must be provided");
    }

    @Test
    void shouldRejectInvalidTitleValues() {

        assertThatThrownBy(() -> command(
                PatchField.provided(null),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("title value must not be null");

        assertThatThrownBy(() -> command(
                PatchField.provided(""),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title value must not be blank");

        assertThatThrownBy(() -> command(
                PatchField.provided("   "),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title value must not be blank");

        assertThatThrownBy(() -> command(
                PatchField.provided("a".repeat(256)),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided()
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title value must not exceed 255 characters");
    }

    @Test
    void shouldRejectTooLongPlaceName() {

        assertThatThrownBy(() -> command(
                notProvided(),
                notProvided(),
                PatchField.provided("a".repeat(256)),
                notProvided(),
                notProvided(),
                notProvided()
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("placeName value must not exceed 255 characters");
    }

    @Test
    void shouldRejectHalfLocationPatch() {

        assertThatThrownBy(() -> command(
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(41.715137),
                notProvided(),
                notProvided()
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("latitude and longitude must be provided together");

        assertThatThrownBy(() -> command(
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(44.827096),
                notProvided()
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("latitude and longitude must be provided together");
    }

    @Test
    void shouldRejectNullCoordinates() {

        assertThatThrownBy(() -> command(
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(null),
                PatchField.provided(44.827096),
                notProvided()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("latitude value must not be null");

        assertThatThrownBy(() -> command(
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(41.715137),
                PatchField.provided(null),
                notProvided()
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("longitude value must not be null");
    }

    @Test
    void shouldRejectInvalidCoordinateValues() {

        assertInvalidLatitude(Double.NaN);
        assertInvalidLatitude(Double.POSITIVE_INFINITY);
        assertInvalidLatitude(Double.NEGATIVE_INFINITY);
        assertInvalidLatitude(-90.000001);
        assertInvalidLatitude(90.000001);

        assertInvalidLongitude(Double.NaN);
        assertInvalidLongitude(Double.POSITIVE_INFINITY);
        assertInvalidLongitude(Double.NEGATIVE_INFINITY);
        assertInvalidLongitude(-180.000001);
        assertInvalidLongitude(180.000001);
    }

    @Test
    void shouldRejectNullEventDate() {

        assertThatThrownBy(() -> command(
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(null)
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("eventDate value must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {

        UpdateMemoryCommand first = command(
                PatchField.provided("Updated memory"),
                PatchField.provided("Updated description"),
                PatchField.provided("Tbilisi"),
                PatchField.provided(41.715137),
                PatchField.provided(44.827096),
                PatchField.provided(EVENT_DATE)
        );
        UpdateMemoryCommand second = command(
                PatchField.provided("Updated memory"),
                PatchField.provided("Updated description"),
                PatchField.provided("Tbilisi"),
                PatchField.provided(41.715137),
                PatchField.provided(44.827096),
                PatchField.provided(EVENT_DATE)
        );
        UpdateMemoryCommand different = command(
                PatchField.provided("Another memory"),
                PatchField.provided("Updated description"),
                PatchField.provided("Tbilisi"),
                PatchField.provided(41.715137),
                PatchField.provided(44.827096),
                PatchField.provided(EVENT_DATE)
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldExposeOnlyAllowedRecordComponents() {

        Set<String> components = Arrays.stream(
                        UpdateMemoryCommand.class.getRecordComponents()
                )
                .map(RecordComponent::getName)
                .collect(Collectors.toSet());

        assertThat(components).containsExactlyInAnyOrder(
                "authenticatedUser",
                "memoryId",
                "title",
                "description",
                "placeName",
                "latitude",
                "longitude",
                "eventDate",
                "currentTime"
        );
        assertThat(components)
                .doesNotContain(
                        "storyId",
                        "createdBy",
                        "role",
                        "ownerId",
                        "createdAt",
                        "updatedAt",
                        "memory",
                        "repository",
                        "media",
                        "photos"
                );
    }

    @Test
    void shouldUseSafeToString() {

        UpdateMemoryCommand command = new UpdateMemoryCommand(
                AUTHENTICATED_USER,
                MEMORY_ID,
                PatchField.provided("Secret title"),
                PatchField.provided("Secret description"),
                PatchField.provided("Secret place"),
                PatchField.provided(41.715137),
                PatchField.provided(44.827096),
                PatchField.provided(EVENT_DATE),
                CURRENT_TIME
        );

        assertThat(command.toString())
                .contains("updatesTitle=true")
                .contains("updatesDescription=true")
                .contains("updatesPlaceName=true")
                .contains("updatesLocation=true")
                .contains("updatesEventDate=true")
                .doesNotContain(USER_ID.toString())
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain("Secret title")
                .doesNotContain("Secret description")
                .doesNotContain("Secret place")
                .doesNotContain("41.715137")
                .doesNotContain("44.827096")
                .doesNotContain(EVENT_DATE.toString())
                .doesNotContain(CURRENT_TIME.toString());
    }

    private static UpdateMemoryCommand command(
            PatchField<String> title,
            PatchField<String> description,
            PatchField<String> placeName,
            PatchField<Double> latitude,
            PatchField<Double> longitude,
            PatchField<LocalDate> eventDate
    ) {
        return new UpdateMemoryCommand(
                AUTHENTICATED_USER,
                MEMORY_ID,
                title,
                description,
                placeName,
                latitude,
                longitude,
                eventDate,
                CURRENT_TIME
        );
    }

    private static UpdateMemoryCommand commandWithCurrentTime(
            Instant currentTime
    ) {
        return new UpdateMemoryCommand(
                AUTHENTICATED_USER,
                MEMORY_ID,
                title(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                notProvided(),
                currentTime
        );
    }

    private static void assertNullPatchFieldRejected(String fieldName) {
        PatchField<String> title = title();
        PatchField<String> description = notProvided();
        PatchField<String> placeName = notProvided();
        PatchField<Double> latitude = notProvided();
        PatchField<Double> longitude = notProvided();
        PatchField<LocalDate> eventDate = notProvided();

        switch (fieldName) {
            case "title" -> title = null;
            case "description" -> description = null;
            case "placeName" -> placeName = null;
            case "latitude" -> latitude = null;
            case "longitude" -> longitude = null;
            case "eventDate" -> eventDate = null;
            default -> throw new AssertionError(fieldName);
        }

        PatchField<String> finalTitle = title;
        PatchField<String> finalDescription = description;
        PatchField<String> finalPlaceName = placeName;
        PatchField<Double> finalLatitude = latitude;
        PatchField<Double> finalLongitude = longitude;
        PatchField<LocalDate> finalEventDate = eventDate;

        assertThatThrownBy(() -> command(
                finalTitle,
                finalDescription,
                finalPlaceName,
                finalLatitude,
                finalLongitude,
                finalEventDate
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage(fieldName + " must not be null");
    }

    private static void assertInvalidLatitude(Double latitude) {
        assertThatThrownBy(() -> command(
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(latitude),
                PatchField.provided(44.827096),
                notProvided()
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("latitude value must be between -90 and 90");
    }

    private static void assertInvalidLongitude(Double longitude) {
        assertThatThrownBy(() -> command(
                notProvided(),
                notProvided(),
                notProvided(),
                PatchField.provided(41.715137),
                PatchField.provided(longitude),
                notProvided()
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("longitude value must be between -180 and 180");
    }

    private static PatchField<String> title() {
        return PatchField.provided("Updated memory");
    }

    private static <T> PatchField<T> notProvided() {
        return PatchField.notProvided();
    }
}
