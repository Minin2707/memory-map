package memory_map.backend.invite.domain;

import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class InviteTest {

    private static final UUID INVITE_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final Instant CREATED_AT =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Instant EXPIRES_AT =
            Instant.parse("2026-01-02T10:00:00Z");

    @Test
    void shouldStoreInviteRole() {

        Invite invite = invite(StoryRole.EDITOR);

        assertThat(invite.role()).isEqualTo(StoryRole.EDITOR);
    }

    @Test
    void shouldRejectNullRole() {

        assertThatThrownBy(() -> invite(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("role must not be null");
    }

    @Test
    void shouldRejectOwnerRole() {

        assertThatThrownBy(() -> invite(StoryRole.OWNER))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("role must not be OWNER");
    }

    private static Invite invite(StoryRole role) {
        return new Invite(
                INVITE_ID,
                STORY_ID,
                role,
                "token-hash",
                USER_ID,
                CREATED_AT,
                EXPIRES_AT,
                null
        );
    }
}
