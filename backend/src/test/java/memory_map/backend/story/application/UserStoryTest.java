package memory_map.backend.story.application;

import memory_map.backend.story.domain.Story;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UserStoryTest {

    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID MEDIA_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00Z");
    private static final Story STORY = new Story(
            STORY_ID,
            OWNER_ID,
            "Our Story",
            "The beginning",
            CURRENT_TIME,
            CURRENT_TIME
    );

    @Test
    void shouldCreateUserStoryWhenRequiredFieldsAreValid() {

        UserStory userStory = new UserStory(
                STORY,
                StoryRole.OWNER
        );

        assertThat(userStory.story()).isEqualTo(STORY);
        assertThat(userStory.role()).isEqualTo(StoryRole.OWNER);
        assertThat(userStory.memoryCount()).isZero();
        assertThat(userStory.participantCount()).isEqualTo(1);
        assertThat(userStory.previewPhoto()).isNull();
    }

    @Test
    void shouldCreateUserStoryWithProjectionMetadata() {

        StoryPhotoPreview previewPhoto = new StoryPhotoPreview(MEDIA_ID);

        UserStory userStory = new UserStory(
                STORY,
                StoryRole.CO_OWNER,
                3,
                2,
                previewPhoto
        );

        assertThat(userStory.story()).isEqualTo(STORY);
        assertThat(userStory.role()).isEqualTo(StoryRole.CO_OWNER);
        assertThat(userStory.memoryCount()).isEqualTo(3);
        assertThat(userStory.participantCount()).isEqualTo(2);
        assertThat(userStory.previewPhoto()).isEqualTo(previewPhoto);
    }

    @Test
    void shouldRejectNullStory() {

        assertThatThrownBy(() -> new UserStory(
                null,
                StoryRole.OWNER
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("story must not be null");
    }

    @Test
    void shouldRejectNullRole() {

        assertThatThrownBy(() -> new UserStory(
                STORY,
                null
        ))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("role must not be null");
    }

    @Test
    void shouldRejectNegativeMemoryCount() {

        assertThatThrownBy(() -> new UserStory(
                STORY,
                StoryRole.OWNER,
                -1,
                1,
                null
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("memoryCount must not be negative");
    }

    @Test
    void shouldRejectNonPositiveParticipantCount() {

        assertThatThrownBy(() -> new UserStory(
                STORY,
                StoryRole.OWNER,
                0,
                0,
                null
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("participantCount must be positive");
    }

    @Test
    void shouldPreserveValueSemantics() {

        UserStory first = new UserStory(
                STORY,
                StoryRole.OWNER,
                2,
                3,
                new StoryPhotoPreview(MEDIA_ID)
        );
        UserStory second = new UserStory(
                STORY,
                StoryRole.OWNER,
                2,
                3,
                new StoryPhotoPreview(MEDIA_ID)
        );
        UserStory different = new UserStory(
                STORY,
                StoryRole.EDITOR,
                2,
                3,
                new StoryPhotoPreview(MEDIA_ID)
        );

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldHaveSafeToString() {

        UserStory userStory = new UserStory(
                STORY,
                StoryRole.OWNER,
                4,
                2,
                new StoryPhotoPreview(MEDIA_ID)
        );

        assertThat(userStory.toString())
                .isEqualTo(
                        "UserStory[role=OWNER, memoryCount=4, participantCount=2, hasPreviewPhoto=true]"
                )
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(MEDIA_ID.toString())
                .doesNotContain("Our Story")
                .doesNotContain("The beginning");
    }
}
