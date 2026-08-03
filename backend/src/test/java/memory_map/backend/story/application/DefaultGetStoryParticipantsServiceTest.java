package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.story.repository.StoryParticipantViewRepository;
import memory_map.backend.storyparticipant.domain.StoryRole;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultGetStoryParticipantsServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID OTHER_USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final Instant JOINED_AT =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);

    @Test
    void shouldReturnParticipants() {

        StoryParticipantView first = participantView(
                USER_ID,
                "Konstantin",
                null,
                StoryRole.OWNER,
                JOINED_AT
        );
        StoryParticipantView second = participantView(
                OTHER_USER_ID,
                "Olga",
                "https://example.com/avatar.png",
                StoryRole.VIEWER,
                JOINED_AT.plusSeconds(1)
        );
        TestContext context = testContext(List.of(first, second));

        List<StoryParticipantView> result =
                context.service().getParticipants(
                        AUTHENTICATED_USER,
                        STORY_ID
                );

        assertThat(result).containsExactly(first, second);
    }

    @Test
    void shouldPassStoryIdAndAuthenticatedUserId() {

        TestContext context = testContext(List.of(participantView(
                USER_ID,
                "Konstantin",
                null,
                StoryRole.OWNER,
                JOINED_AT
        )));

        context.service().getParticipants(AUTHENTICATED_USER, STORY_ID);

        assertThat(context.repository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.repository().receivedRequesterUserId())
                .isEqualTo(USER_ID);
        assertThat(context.repository().callCount()).isEqualTo(1);
    }

    @Test
    void shouldReturnExactRepositoryResult() {

        List<StoryParticipantView> participants = List.of(participantView(
                USER_ID,
                "Konstantin",
                null,
                StoryRole.CO_OWNER,
                JOINED_AT
        ));
        TestContext context = testContext(participants);

        List<StoryParticipantView> result =
                context.service().getParticipants(
                        AUTHENTICATED_USER,
                        STORY_ID
                );

        assertThat(result).isSameAs(participants);
    }

    @Test
    void shouldPreserveReturnedOrder() {

        StoryParticipantView first = participantView(
                OTHER_USER_ID,
                "Olga",
                null,
                StoryRole.EDITOR,
                JOINED_AT.plusSeconds(2)
        );
        StoryParticipantView second = participantView(
                USER_ID,
                "Konstantin",
                null,
                StoryRole.OWNER,
                JOINED_AT
        );
        TestContext context = testContext(List.of(first, second));

        List<StoryParticipantView> result =
                context.service().getParticipants(
                        AUTHENTICATED_USER,
                        STORY_ID
                );

        assertThat(result).containsExactly(first, second);
    }

    @Test
    void shouldThrowStoryNotFoundWhenRepositoryReturnsEmpty() {

        TestContext context = testContext(List.of());

        assertThatThrownBy(() -> context.service().getParticipants(
                AUTHENTICATED_USER,
                STORY_ID
        ))
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");
    }

    @Test
    void shouldUseSameFailureForMissingOrInaccessibleOutcome() {

        StoryNotFoundException missing = catchStoryNotFound(
                testContext(List.of()),
                STORY_ID
        );
        StoryNotFoundException inaccessible = catchStoryNotFound(
                testContext(List.of()),
                UUID.fromString("00000000-0000-0000-0000-000000000004")
        );

        assertThat(missing).hasMessage("Story was not found");
        assertThat(inaccessible).hasMessage("Story was not found");
        assertThat(missing.getClass()).isEqualTo(inaccessible.getClass());
        assertThat(missing.getMessage())
                .isEqualTo(inaccessible.getMessage());
    }

    @Test
    void shouldRejectNullRepositoryDependency() {

        assertThatThrownBy(() -> new DefaultGetStoryParticipantsService(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("repository must not be null");
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> testContext(List.of(participantView(
                USER_ID,
                "Konstantin",
                null,
                StoryRole.OWNER,
                JOINED_AT
        ))).service().getParticipants(null, STORY_ID))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullStoryId() {

        assertThatThrownBy(() -> testContext(List.of(participantView(
                USER_ID,
                "Konstantin",
                null,
                StoryRole.OWNER,
                JOINED_AT
        ))).service().getParticipants(AUTHENTICATED_USER, null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldPropagateRepositoryFailure() {

        RuntimeException failure =
                new RuntimeException("repository failed");
        TestContext context = testContext(List.of());
        context.repository().failWith(failure);

        assertThatThrownBy(() -> context.service().getParticipants(
                AUTHENTICATED_USER,
                STORY_ID
        ))
                .isSameAs(failure);
    }

    @Test
    void shouldNotExposeAccessDeniedDetails() {

        TestContext context = testContext(List.of());

        StoryNotFoundException exception = catchStoryNotFound(
                context,
                STORY_ID
        );

        assertThat(exception.getMessage())
                .isEqualTo("Story was not found")
                .doesNotContain(STORY_ID.toString())
                .doesNotContain(USER_ID.toString())
                .doesNotContain("role")
                .doesNotContain("access");
    }

    private static StoryNotFoundException catchStoryNotFound(
            TestContext context,
            UUID storyId
    ) {
        try {
            context.service().getParticipants(AUTHENTICATED_USER, storyId);
        } catch (StoryNotFoundException exception) {
            return exception;
        }

        throw new AssertionError("Expected StoryNotFoundException");
    }

    private static TestContext testContext(
            List<StoryParticipantView> participants
    ) {
        FakeStoryParticipantViewRepository repository =
                new FakeStoryParticipantViewRepository(participants);

        return new TestContext(
                new DefaultGetStoryParticipantsService(repository),
                repository
        );
    }

    private static StoryParticipantView participantView(
            UUID userId,
            String displayName,
            String avatarUrl,
            StoryRole role,
            Instant joinedAt
    ) {
        return new StoryParticipantView(
                userId,
                displayName,
                avatarUrl,
                role,
                joinedAt
        );
    }

    private record TestContext(

            DefaultGetStoryParticipantsService service,

            FakeStoryParticipantViewRepository repository

    ) {
    }

    private static final class FakeStoryParticipantViewRepository
            implements StoryParticipantViewRepository {

        private final List<StoryParticipantView> participants;
        private UUID receivedStoryId;
        private UUID receivedRequesterUserId;
        private int callCount;
        private RuntimeException failure;

        private FakeStoryParticipantViewRepository(
                List<StoryParticipantView> participants
        ) {
            this.participants = participants;
        }

        @Override
        public List<StoryParticipantView> findByStoryIdAndRequesterUserId(
                UUID storyId,
                UUID requesterUserId
        ) {
            receivedStoryId = storyId;
            receivedRequesterUserId = requesterUserId;
            callCount++;

            if (failure != null) {
                throw failure;
            }

            return participants;
        }

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private UUID receivedRequesterUserId() {
            return receivedRequesterUserId;
        }

        private int callCount() {
            return callCount;
        }

        private void failWith(RuntimeException failure) {
            this.failure = failure;
        }
    }
}
