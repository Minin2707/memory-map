package memory_map.backend.media.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import org.junit.jupiter.api.Test;

import java.lang.reflect.RecordComponent;
import java.util.Arrays;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DeleteMediaCommandTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000031");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);

    @Test
    void shouldCreateCommandWhenRequiredFieldsAreValid() {
        DeleteMediaCommand command = new DeleteMediaCommand(
                AUTHENTICATED_USER,
                MEDIA_ID
        );

        assertThat(command.authenticatedUser()).isEqualTo(AUTHENTICATED_USER);
        assertThat(command.mediaId()).isEqualTo(MEDIA_ID);
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {
        assertThatThrownBy(() -> new DeleteMediaCommand(null, MEDIA_ID))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullMediaId() {
        assertThatThrownBy(() -> new DeleteMediaCommand(
                AUTHENTICATED_USER,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("mediaId must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {
        DeleteMediaCommand first = new DeleteMediaCommand(
                AUTHENTICATED_USER,
                MEDIA_ID
        );
        DeleteMediaCommand second = new DeleteMediaCommand(
                AUTHENTICATED_USER,
                MEDIA_ID
        );
        DeleteMediaCommand different = new DeleteMediaCommand(
                AUTHENTICATED_USER,
                UUID.fromString("00000000-0000-0000-0000-000000000032")
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldUseSafeToString() {
        DeleteMediaCommand command = new DeleteMediaCommand(
                AUTHENTICATED_USER,
                MEDIA_ID
        );

        assertThat(command.toString())
                .isEqualTo("DeleteMediaCommand()")
                .doesNotContain(USER_ID.toString())
                .doesNotContain(MEDIA_ID.toString())
                .doesNotContain("authenticatedUser")
                .doesNotContain("mediaId")
                .doesNotContain("memoryId")
                .doesNotContain("storyId")
                .doesNotContain("storage");
    }

    @Test
    void shouldContainOnlyDeleteBoundaryFields() {
        assertThat(recordComponentNames())
                .containsExactly("authenticatedUser", "mediaId");
    }

    private static String[] recordComponentNames() {
        return Arrays.stream(DeleteMediaCommand.class.getRecordComponents())
                .map(RecordComponent::getName)
                .toArray(String[]::new);
    }
}
