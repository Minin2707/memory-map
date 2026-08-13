package memory_map.backend.memory.application;

import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.memory.domain.Memory;
import memory_map.backend.memory.repository.MemoryReadRepository;
import memory_map.backend.story.application.StoryNotFoundException;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DefaultGetStoryMemoriesServiceTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final UUID STORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000002");
    private static final UUID MEMORY_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000003");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-01T10:00:00.123456Z");
    private static final AuthenticatedUser AUTHENTICATED_USER =
            new AuthenticatedUser(USER_ID);

    @Test
    void shouldReturnAccessibleMemories() {

        Memory memory = memory(MEMORY_ID, "First");
        MemoryReadModel readModel = MemoryReadModel.withoutPreview(memory);
        TestContext context = testContext(Optional.of(
                new StoryMemoriesView(List.of(readModel))
        ));

        List<MemoryReadModel> result = context.service().getMemories(
                AUTHENTICATED_USER,
                STORY_ID
        );

        assertThat(result).containsExactly(readModel);
    }

    @Test
    void shouldPassStoryIdAndAuthenticatedUserId() {

        TestContext context = testContext(Optional.of(
                new StoryMemoriesView(List.of(
                        MemoryReadModel.withoutPreview(
                                memory(MEMORY_ID, "First")
                        )
                ))
        ));

        context.service().getMemories(AUTHENTICATED_USER, STORY_ID);

        assertThat(context.repository().receivedStoryId())
                .isEqualTo(STORY_ID);
        assertThat(context.repository().receivedRequesterUserId())
                .isEqualTo(USER_ID);
        assertThat(context.repository().storyListCallCount()).isEqualTo(1);
        assertThat(context.repository().memoryGetCallCount()).isZero();
    }

    @Test
    void shouldPreserveRepositoryOrder() {

        Memory second = memory(
                UUID.fromString("00000000-0000-0000-0000-000000000004"),
                "Second"
        );
        Memory first = memory(MEMORY_ID, "First");
        TestContext context = testContext(Optional.of(
                new StoryMemoriesView(List.of(
                        MemoryReadModel.withoutPreview(second),
                        MemoryReadModel.withoutPreview(first)
                ))
        ));

        List<MemoryReadModel> result = context.service().getMemories(
                AUTHENTICATED_USER,
                STORY_ID
        );

        assertThat(result).extracting(MemoryReadModel::memory)
                .containsExactly(second, first);
    }

    @Test
    void shouldReturnAccessibleEmptyList() {

        TestContext context = testContext(Optional.of(
                new StoryMemoriesView(List.of())
        ));

        List<MemoryReadModel> result = context.service().getMemories(
                AUTHENTICATED_USER,
                STORY_ID
        );

        assertThat(result).isEmpty();
    }

    @Test
    void shouldReturnImmutableListFromView() {

        TestContext context = testContext(Optional.of(
                new StoryMemoriesView(List.of(
                        MemoryReadModel.withoutPreview(
                                memory(MEMORY_ID, "First")
                        )
                ))
        ));

        List<MemoryReadModel> result = context.service().getMemories(
                AUTHENTICATED_USER,
                STORY_ID
        );

        assertThatThrownBy(() -> result.add(MemoryReadModel.withoutPreview(
                memory(MEMORY_ID, "First")
        )))
                .isInstanceOf(UnsupportedOperationException.class);
    }

    @Test
    void shouldThrowStoryNotFoundWhenStoryIsUnavailable() {

        TestContext context = testContext(Optional.empty());

        assertThatThrownBy(() -> context.service().getMemories(
                AUTHENTICATED_USER,
                STORY_ID
        ))
                .isInstanceOf(StoryNotFoundException.class)
                .hasMessage("Story was not found");
    }

    @Test
    void shouldRejectNullRepositoryDependency() {

        assertThatThrownBy(() -> new DefaultGetStoryMemoriesService(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("repository must not be null");
    }

    @Test
    void shouldRejectNullAuthenticatedUser() {

        assertThatThrownBy(() -> testContext(Optional.of(
                new StoryMemoriesView(List.of())
        )).service().getMemories(null, STORY_ID))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("authenticatedUser must not be null");
    }

    @Test
    void shouldRejectNullStoryId() {

        assertThatThrownBy(() -> testContext(Optional.of(
                new StoryMemoriesView(List.of())
        )).service().getMemories(AUTHENTICATED_USER, null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("storyId must not be null");
    }

    @Test
    void shouldPropagateRepositoryFailure() {

        RuntimeException failure = new RuntimeException("repository failed");
        TestContext context = testContext(Optional.empty());
        context.repository().failWith(failure);

        assertThatThrownBy(() -> context.service().getMemories(
                AUTHENTICATED_USER,
                STORY_ID
        ))
                .isSameAs(failure);
    }

    private static TestContext testContext(
            Optional<StoryMemoriesView> storyMemories
    ) {
        FakeMemoryReadRepository repository =
                new FakeMemoryReadRepository(storyMemories);

        return new TestContext(
                new DefaultGetStoryMemoriesService(repository),
                repository
        );
    }

    private static Memory memory(UUID id, String title) {
        return new Memory(
                id,
                STORY_ID,
                USER_ID,
                title,
                "A spring walk",
                "Tbilisi",
                41.715137,
                44.827096,
                LocalDate.of(2025, 5, 20),
                CURRENT_TIME,
                CURRENT_TIME
        );
    }

    private record TestContext(

            DefaultGetStoryMemoriesService service,

            FakeMemoryReadRepository repository

    ) {
    }

    private static final class FakeMemoryReadRepository
            implements MemoryReadRepository {

        private final Optional<StoryMemoriesView> storyMemories;
        private UUID receivedStoryId;
        private UUID receivedRequesterUserId;
        private int storyListCallCount;
        private int memoryGetCallCount;
        private RuntimeException failure;

        private FakeMemoryReadRepository(
                Optional<StoryMemoriesView> storyMemories
        ) {
            this.storyMemories = storyMemories;
        }

        @Override
        public Optional<StoryMemoriesView> findByStoryIdAndRequesterUserId(
                UUID storyId,
                UUID requesterUserId
        ) {
            receivedStoryId = storyId;
            receivedRequesterUserId = requesterUserId;
            storyListCallCount++;

            if (failure != null) {
                throw failure;
            }

            return storyMemories;
        }

        @Override
        public Optional<MemoryReadModel> findByIdAndRequesterUserId(
                UUID memoryId,
                UUID requesterUserId
        ) {
            memoryGetCallCount++;
            return Optional.empty();
        }

        private UUID receivedStoryId() {
            return receivedStoryId;
        }

        private UUID receivedRequesterUserId() {
            return receivedRequesterUserId;
        }

        private int storyListCallCount() {
            return storyListCallCount;
        }

        private int memoryGetCallCount() {
            return memoryGetCallCount;
        }

        private void failWith(RuntimeException failure) {
            this.failure = failure;
        }
    }
}
