package memory_map.backend.invite.application;

import org.junit.jupiter.api.Test;

import java.lang.reflect.RecordComponent;
import java.net.URI;
import java.time.Instant;
import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class CreatedInviteTest {

    private static final String RAW_TOKEN =
            "abcdefghijklmnopqrstuvwxyzABCDE_0123456789-";
    private static final URI INVITE_LINK =
            URI.create("https://app.memorymap.app/invite/" + RAW_TOKEN);
    private static final Instant EXPIRES_AT =
            Instant.parse("2026-01-31T10:00:00Z");

    @Test
    void shouldCreateResultWhenFieldsAreValid() {

        CreatedInvite result = new CreatedInvite(
                INVITE_LINK,
                EXPIRES_AT
        );

        assertThat(result.inviteLink()).isEqualTo(INVITE_LINK);
        assertThat(result.expiresAt()).isEqualTo(EXPIRES_AT);
    }

    @Test
    void shouldRejectNullInviteLink() {

        assertThatThrownBy(() -> new CreatedInvite(
                null,
                EXPIRES_AT
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("inviteLink must not be null");
    }

    @Test
    void shouldRejectNullExpiresAt() {

        assertThatThrownBy(() -> new CreatedInvite(
                INVITE_LINK,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("expiresAt must not be null");
    }

    @Test
    void shouldRejectRelativeInviteLink() {

        assertThatThrownBy(() -> new CreatedInvite(
                URI.create("/invite/" + RAW_TOKEN),
                EXPIRES_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("inviteLink must be absolute");
    }

    @Test
    void shouldRejectInviteLinkWithDisallowedScheme() {

        assertThatThrownBy(() -> new CreatedInvite(
                URI.create("ftp://app.memorymap.app/invite/" + RAW_TOKEN),
                EXPIRES_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("inviteLink scheme must be http or https");
    }

    @Test
    void shouldRejectInviteLinkWithoutHost() {

        assertThatThrownBy(() -> new CreatedInvite(
                URI.create("https:/invite/" + RAW_TOKEN),
                EXPIRES_AT
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("inviteLink host must not be null");
    }

    @Test
    void shouldPreserveValueSemantics() {

        CreatedInvite first = new CreatedInvite(INVITE_LINK, EXPIRES_AT);
        CreatedInvite second = new CreatedInvite(INVITE_LINK, EXPIRES_AT);
        CreatedInvite different = new CreatedInvite(
                INVITE_LINK,
                EXPIRES_AT.plusSeconds(1)
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldUseSafeToString() {

        CreatedInvite result = new CreatedInvite(
                INVITE_LINK,
                EXPIRES_AT
        );

        assertThat(result.toString())
                .contains("inviteLink=<redacted>")
                .contains(EXPIRES_AT.toString())
                .doesNotContain(RAW_TOKEN)
                .doesNotContain("app.memorymap.app")
                .doesNotContain("/invite/")
                .doesNotContain("https://");
    }

    @Test
    void shouldContainOnlyResultFields() {

        assertThat(recordComponentNames())
                .containsExactly("inviteLink", "expiresAt");
    }

    @Test
    void shouldNotContainTokenHashStoryUserOrRoleFields() {

        assertThat(recordComponentNames())
                .doesNotContain(
                        "rawToken",
                        "tokenHash",
                        "inviteId",
                        "storyId",
                        "userId",
                        "createdBy",
                        "role",
                        "targetRole"
                );
    }

    private static String[] recordComponentNames() {
        return Arrays.stream(CreatedInvite.class.getRecordComponents())
                .map(RecordComponent::getName)
                .toArray(String[]::new);
    }
}
