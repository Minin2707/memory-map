package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import java.lang.reflect.RecordComponent;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class CreateMemoryCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final LocalDate EVENT_DATE =
            LocalDate.of(2024, 5, 20);
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");

    @Test
    void shouldCreateCommandWhenRequiredFieldsAreValid() {

        CreateMemoryCommand command = validCommand();

        assertThat(command.authenticatedUser())
                .isEqualTo(AUTHENTICATED_USER);
        assertThat(command.storyId()).isEqualTo(STORY_ID);
        assertThat(command.memoryId()).isEqualTo(MEMORY_ID);
        assertThat(command.title()).isEqualTo("First trip");
        assertThat(command.description()).isEqualTo("A spring walk");
        assertThat(command.placeName()).isEqualTo("Tbilisi");
        assertThat(command.latitude()).isEqualTo(41.715137);
        assertThat(command.longitude()).isEqualTo(44.827096);
        assertThat(command.eventDate()).isEqualTo(EVENT_DATE);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldAllowNullableDescriptionAndPlaceName() {

        CreateMemoryCommand command = new CreateMemoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                MEMORY_ID,
                "First trip",
                null,
                null,
                41.715137,
                44.827096,
                EVENT_DATE,
                CURRENT_TIME
        );

        assertThat(command.description()).isNull();
        assertThat(command.placeName()).isNull();
    }

    @Test
    void shouldPreserveStringsWithoutNormalization() {

        CreateMemoryCommand command = new CreateMemoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                MEMORY_ID,
                "  First trip  ",
                "",
                "  Tbilisi  ",
                41.715137,
                44.827096,
                EVENT_DATE,
                CURRENT_TIME
        );

        assertThat(command.title()).isEqualTo("  First trip  ");
        assertThat(command.description()).isEqualTo("");
        assertThat(command.placeName()).isEqualTo("  Tbilisi  ");
    }

    @Test
    void shouldAllowFutureEventDateIndependentOfCurrentTime() {

        LocalDate futureEventDate = LocalDate.of(2030, 1, 1);

        CreateMemoryCommand command = new CreateMemoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                MEMORY_ID,
                "Future memory",
                null,
                null,
                41.715137,
                44.827096,
                futureEventDate,
                CURRENT_TIME
        );

        assertThat(command.eventDate()).isEqualTo(futureEventDate);
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
    }

    @Test
    void shouldAllowCoordinateBoundaries() {

        CreateMemoryCommand southwest = commandWithCoordinates(-90.0, -180.0);
        CreateMemoryCommand northeast = commandWithCoordinates(90.0, 180.0);

        assertThat(southwest.latitude()).isEqualTo(-90.0);
        assertThat(southwest.longitude()).isEqualTo(-180.0);
        assertThat(northeast.latitude()).isEqualTo(90.0);
        assertThat(northeast.longitude()).isEqualTo(180.0);
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> new CreateMemoryCommand(
                null,
                STORY_ID,
                MEMORY_ID,
                "First trip",
                null,
                null,
                41.715137,
                44.827096,
                EVENT_DATE,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullStoryId() {

        assertThatThrownBy(() -> new CreateMemoryCommand(
                AUTHENTICATED_USER,
                null,
                MEMORY_ID,
                "First trip",
                null,
                null,
                41.715137,
                44.827096,
                EVENT_DATE,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldRejectNullMemoryId() {

        assertThatThrownBy(() -> new CreateMemoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                null,
                "First trip",
                null,
                null,
                41.715137,
                44.827096,
                EVENT_DATE,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memoryId must not be null");
    }

    @Test
    void shouldRejectNullTitle() {

        assertThatThrownBy(() -> new CreateMemoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                MEMORY_ID,
                null,
                null,
                null,
                41.715137,
                44.827096,
                EVENT_DATE,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("title must not be null");
    }

    @Test
    void shouldRejectBlankTitle() {

        assertThatThrownBy(() -> commandWithTitle(""))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title must not be blank");

        assertThatThrownBy(() -> commandWithTitle("   "))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title must not be blank");
    }

    @Test
    void shouldRejectTitleLongerThan255Characters() {

        CreateMemoryCommand command = commandWithTitle("a".repeat(255));

        assertThat(command.title()).hasSize(255);

        assertThatThrownBy(() -> commandWithTitle("a".repeat(256)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("title must not exceed 255 characters");
    }

    @Test
    void shouldRejectPlaceNameLongerThan255Characters() {

        CreateMemoryCommand command = commandWithPlaceName("a".repeat(255));

        assertThat(command.placeName()).hasSize(255);

        assertThatThrownBy(() -> commandWithPlaceName("a".repeat(256)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("placeName must not exceed 255 characters");
    }

    @Test
    void shouldRejectInvalidLatitude() {

        assertThatThrownBy(() -> commandWithCoordinates(Double.NaN, 44.827096))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("latitude must be between -90 and 90");

        assertThatThrownBy(() ->
                commandWithCoordinates(Double.POSITIVE_INFINITY, 44.827096)
        )
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("latitude must be between -90 and 90");

        assertThatThrownBy(() -> commandWithCoordinates(-90.000001, 44.827096))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("latitude must be between -90 and 90");

        assertThatThrownBy(() -> commandWithCoordinates(90.000001, 44.827096))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("latitude must be between -90 and 90");
    }

    @Test
    void shouldRejectInvalidLongitude() {

        assertThatThrownBy(() -> commandWithCoordinates(41.715137, Double.NaN))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("longitude must be between -180 and 180");

        assertThatThrownBy(() ->
                commandWithCoordinates(41.715137, Double.NEGATIVE_INFINITY)
        )
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("longitude must be between -180 and 180");

        assertThatThrownBy(() -> commandWithCoordinates(41.715137, -180.000001))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("longitude must be between -180 and 180");

        assertThatThrownBy(() -> commandWithCoordinates(41.715137, 180.000001))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("longitude must be between -180 and 180");
    }

    @Test
    void shouldRejectNullEventDate() {

        assertThatThrownBy(() -> new CreateMemoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                MEMORY_ID,
                "First trip",
                null,
                null,
                41.715137,
                44.827096,
                null,
                CURRENT_TIME
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("eventDate must not be null");
    }

    @Test
    void shouldRejectNullCurrentTime() {

        assertThatThrownBy(() -> new CreateMemoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                MEMORY_ID,
                "First trip",
                null,
                null,
                41.715137,
                44.827096,
                EVENT_DATE,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("currentTime must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {

        CreateMemoryCommand first = validCommand();
        CreateMemoryCommand second = validCommand();
        CreateMemoryCommand different = commandWithTitle("Another title");

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldUseSafeToString() {

        CreateMemoryCommand command = validCommand();
        String text = command.toString();

        assertThat(text)
                .isEqualTo(
                        "CreateMemoryCommand["
                                + "hasDescription=true, "
                                + "hasPlaceName=true"
                                + "]"
                )
                .doesNotContain(USER_ID.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain("First trip")
                .doesNotContain("A spring walk")
                .doesNotContain("Tbilisi")
                .doesNotContain("41.715137")
                .doesNotContain("44.827096")
                .doesNotContain(EVENT_DATE.toString())
                .doesNotContain(CURRENT_TIME.toString());
    }

    @Test
    void shouldContainOnlyCreateMemoryBoundaryFields() {

        assertThat(recordComponentNames())
                .containsExactly(
                        "authenticatedUser",
                        "storyId",
                        "memoryId",
                        "title",
                        "description",
                        "placeName",
                        "latitude",
                        "longitude",
                        "eventDate",
                        "currentTime"
                );
    }

    @Test
    void shouldUseExpectedRecordComponentTypes() {

        assertThat(recordComponentTypes())
                .containsExactly(
                        AuthenticatedUser.class,
                        UUID.class,
                        UUID.class,
                        String.class,
                        String.class,
                        String.class,
                        double.class,
                        double.class,
                        LocalDate.class,
                        Instant.class
                );
    }

    @Test
    void shouldNotContainServerDerivedOrInfrastructureFields() {

        assertThat(recordComponentNames())
                .doesNotContain(
                        "createdBy",
                        "userId",
                        "role",
                        "ownerId",
                        "createdAt",
                        "updatedAt",
                        "media",
                        "photo",
                        "photos",
                        "token",
                        "repository",
                        "clock"
                );
    }

    private static CreateMemoryCommand validCommand() {
        return new CreateMemoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                MEMORY_ID,
                "First trip",
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                EVENT_DATE,
                CURRENT_TIME
        );
    }

    private static CreateMemoryCommand commandWithTitle(String title) {
        return new CreateMemoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                MEMORY_ID,
                title,
                null,
                null,
                41.715137,
                44.827096,
                EVENT_DATE,
                CURRENT_TIME
        );
    }

    private static CreateMemoryCommand commandWithPlaceName(String placeName) {
        return new CreateMemoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                MEMORY_ID,
                "First trip",
                null,
                placeName,
                41.715137,
                44.827096,
                EVENT_DATE,
                CURRENT_TIME
        );
    }

    private static CreateMemoryCommand commandWithCoordinates(
            double latitude,
            double longitude
    ) {
        return new CreateMemoryCommand(
                AUTHENTICATED_USER,
                STORY_ID,
                MEMORY_ID,
                "First trip",
                null,
                null,
                latitude,
                longitude,
                EVENT_DATE,
                CURRENT_TIME
        );
    }

    private static String[] recordComponentNames() {
        return Arrays.stream(CreateMemoryCommand.class.getRecordComponents())
                .map(RecordComponent::getName)
                .toArray(String[]::new);
    }

    private static Class<?>[] recordComponentTypes() {
        return Arrays.stream(CreateMemoryCommand.class.getRecordComponents())
                .map(RecordComponent::getType)
                .toArray(Class<?>[]::new);
    }
}
