package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import java.lang.reflect.RecordComponent;
import java.util.Arrays;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DeleteMemoryCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final UUID CREATED_BY =
            UUID.fromString("00000000-0000-0000-0000-000000000004");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000005");

    @Test
    void shouldCreateCommandWhenRequiredFieldsAreValid() {

        DeleteMemoryCommand command = new DeleteMemoryCommand(
                AUTHENTICATED_USER,
                MEMORY_ID
        );

        assertThat(command.authenticatedUser())
                .isEqualTo(AUTHENTICATED_USER);
        assertThat(command.memoryId()).isEqualTo(MEMORY_ID);
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> new DeleteMemoryCommand(
                null,
                MEMORY_ID
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullMemoryId() {

        assertThatThrownBy(() -> new DeleteMemoryCommand(
                AUTHENTICATED_USER,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("memoryId must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {

        DeleteMemoryCommand first = new DeleteMemoryCommand(
                AUTHENTICATED_USER,
                MEMORY_ID
        );
        DeleteMemoryCommand second = new DeleteMemoryCommand(
                AUTHENTICATED_USER,
                MEMORY_ID
        );
        DeleteMemoryCommand different = new DeleteMemoryCommand(
                AUTHENTICATED_USER,
                UUID.fromString("00000000-0000-0000-0000-000000000006")
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldUseSafeToString() {

        DeleteMemoryCommand command = new DeleteMemoryCommand(
                AUTHENTICATED_USER,
                MEMORY_ID
        );

        assertThat(command.toString())
                .isEqualTo("DeleteMemoryCommand()")
                .doesNotContain(USER_ID.toString())
                .doesNotContain(MEMORY_ID.toString())
                .doesNotContain("authenticatedUser")
                .doesNotContain("memoryId")
                .doesNotContain("storyId")
                .doesNotContain("createdBy")
                .doesNotContain("role")
                .doesNotContain("author");
    }

    @Test
    void shouldContainOnlyDeleteBoundaryFields() {

        assertThat(recordComponentNames())
                .containsExactly(
                        "authenticatedUser",
                        "memoryId"
                );
    }

    @Test
    void shouldUseExpectedRecordComponentTypes() {

        assertThat(recordComponentTypes())
                .containsExactly(
                        AuthenticatedUser.class,
                        UUID.class
                );
    }

    @Test
    void shouldNotContainClientChosenAuthorizationOrLifecycleFields() {

        assertThat(recordComponentNames())
                .doesNotContain(
                        "storyId",
                        "createdBy",
                        "userId",
                        "role",
                        "ownerId",
                        "currentTime",
                        "createdAt",
                        "updatedAt",
                        "deletedAt",
                        "reason",
                        "force",
                        "memory",
                        "repository",
                        "media",
                        "photos"
                );
    }

    @Test
    void shouldNotNormalizeOrGenerateIdentifiers() {

        DeleteMemoryCommand command = new DeleteMemoryCommand(
                new AuthenticatedUser(USER_ID),
                MEMORY_ID
        );

        assertThat(command.authenticatedUser().userId()).isEqualTo(USER_ID);
        assertThat(command.memoryId()).isEqualTo(MEMORY_ID);
        assertThat(command.toString())
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(CREATED_BY.toString())
                .doesNotContain(OWNER_ID.toString());
    }

    private static String[] recordComponentNames() {
        return Arrays.stream(DeleteMemoryCommand.class.getRecordComponents())
                .map(RecordComponent::getName)
                .toArray(String[]::new);
    }

    private static Class<?>[] recordComponentTypes() {
        return Arrays.stream(DeleteMemoryCommand.class.getRecordComponents())
                .map(RecordComponent::getType)
                .toArray(Class<?>[]::new);
    }
}
