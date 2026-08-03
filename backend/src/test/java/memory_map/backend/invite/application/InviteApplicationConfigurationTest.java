package memory_map.backend.invite.application;

import memory_map.backend.invite.domain.Invite;
import memory_map.backend.invite.repository.InviteRepository;
import memory_map.backend.story.application.UserStory;
import memory_map.backend.story.domain.Story;
import memory_map.backend.story.repository.StoryRepository;
import memory_map.backend.story.repository.UserStoryRepository;
import memory_map.backend.storyparticipant.domain.StoryParticipant;
import memory_map.backend.storyparticipant.repository.StoryParticipantRepository;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import java.net.URI;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class InviteApplicationConfigurationTest {

    private final ApplicationContextRunner contextRunner =
            new ApplicationContextRunner()
                    .withUserConfiguration(
                            InviteApplicationConfiguration.class
                    )
                    .withPropertyValues(
                            "app.invite.ttl=P30D",
                            "app.invite.base-url=https://app.memorymap.app"
                    )
                    .withBean(
                            UserStoryRepository.class,
                            FakeUserStoryRepository::new
                    )
                    .withBean(
                            InviteRepository.class,
                            FakeInviteRepository::new
                    )
                    .withBean(
                            StoryRepository.class,
                            FakeStoryRepository::new
                    )
                    .withBean(
                            StoryParticipantRepository.class,
                            FakeStoryParticipantRepository::new
                    );

    @Test
    void shouldBindInviteProperties() {

        contextRunner.run(context -> {
            InviteProperties properties =
                    context.getBean(InviteProperties.class);

            assertThat(properties.ttl()).isEqualTo(Duration.ofDays(30));
            assertThat(properties.baseUrl())
                    .isEqualTo(URI.create("https://app.memorymap.app"));
        });
    }

    @Test
    void shouldRegisterInvitePrimitiveBeans() {

        contextRunner.run(context -> {
            assertThat(context).hasSingleBean(InviteTokenGenerator.class);
            assertThat(context).hasSingleBean(InviteTokenHasher.class);
            assertThat(context).hasSingleBean(InviteLinkFactory.class);

            assertThat(context.getBean(InviteTokenGenerator.class))
                    .isInstanceOf(SecureInviteTokenGenerator.class);
            assertThat(context.getBean(InviteTokenHasher.class))
                    .isInstanceOf(Sha256InviteTokenHasher.class);
            assertThat(context.getBean(InviteLinkFactory.class))
                    .isInstanceOf(DefaultInviteLinkFactory.class);
        });
    }

    @Test
    void shouldRegisterCreateInviteUseCaseBean() {

        contextRunner.run(context -> {
            assertThat(context).hasSingleBean(CreateInviteUseCase.class);
            assertThat(context.getBean(CreateInviteUseCase.class))
                    .isInstanceOf(TransactionalCreateInviteService.class);
        });
    }

    @Test
    void shouldRegisterAcceptInviteUseCaseBean() {

        contextRunner.run(context -> {
            assertThat(context).hasSingleBean(AcceptInviteUseCase.class);
            assertThat(context.getBean(AcceptInviteUseCase.class))
                    .isInstanceOf(TransactionalAcceptInviteService.class);
        });
    }

    @Test
    void shouldCreateInviteLinkFromRegisteredFactory() {

        contextRunner.run(context -> {
            URI link = context.getBean(InviteLinkFactory.class)
                    .create("abc_DEF-123");

            assertThat(link)
                    .isEqualTo(URI.create(
                            "https://app.memorymap.app/invite/abc_DEF-123"
                    ));
        });
    }

    @Test
    void shouldFailContextForInvalidTtl() {

        new ApplicationContextRunner()
                .withUserConfiguration(InviteApplicationConfiguration.class)
                .withPropertyValues(
                        "app.invite.ttl=PT0S",
                        "app.invite.base-url=https://app.memorymap.app"
                )
                .withBean(
                        UserStoryRepository.class,
                        FakeUserStoryRepository::new
                )
                .withBean(
                        InviteRepository.class,
                        FakeInviteRepository::new
                )
                .withBean(
                        StoryRepository.class,
                        FakeStoryRepository::new
                )
                .withBean(
                        StoryParticipantRepository.class,
                        FakeStoryParticipantRepository::new
                )
                .run(context -> assertThat(context).hasFailed());
    }

    private static final class FakeUserStoryRepository
            implements UserStoryRepository {

        @Override
        public List<UserStory> findByUserId(UUID userId) {
            return List.of();
        }

        @Override
        public Optional<UserStory> findByStoryIdAndUserId(
                UUID storyId,
                UUID userId
        ) {
            return Optional.empty();
        }
    }

    private static final class FakeInviteRepository
            implements InviteRepository {

        @Override
        public Optional<Invite> findById(UUID id) {
            return Optional.empty();
        }

        @Override
        public Optional<Invite> findByTokenHash(String tokenHash) {
            return Optional.empty();
        }

        @Override
        public Optional<Invite> findByTokenHashForUpdate(String tokenHash) {
            return Optional.empty();
        }

        @Override
        public List<Invite> findByStoryId(UUID storyId) {
            return List.of();
        }

        @Override
        public void save(Invite invite) {
        }

        @Override
        public boolean markUsedIfUnused(UUID inviteId, Instant usedAt) {
            return false;
        }

        @Override
        public void delete(UUID id) {
        }
    }

    private static final class FakeStoryRepository
            implements StoryRepository {

        @Override
        public Story save(Story story) {
            return story;
        }

        @Override
        public Story update(Story story) {
            return story;
        }

        @Override
        public Optional<Story> findById(UUID id) {
            return Optional.empty();
        }

        @Override
        public boolean lockById(UUID id) {
            return false;
        }

        @Override
        public List<Story> findByOwnerId(UUID ownerId) {
            return List.of();
        }
    }

    private static final class FakeStoryParticipantRepository
            implements StoryParticipantRepository {

        @Override
        public Optional<StoryParticipant> find(UUID storyId, UUID userId) {
            return Optional.empty();
        }

        @Override
        public List<StoryParticipant> findByStoryId(UUID storyId) {
            return List.of();
        }

        @Override
        public List<StoryParticipant> findByUserId(UUID userId) {
            return List.of();
        }

        @Override
        public long countOwners(UUID storyId) {
            return 0;
        }

        @Override
        public boolean exists(UUID storyId, UUID userId) {
            return false;
        }

        @Override
        public void save(StoryParticipant participant) {
        }

        @Override
        public void update(StoryParticipant participant) {
        }

        @Override
        public void delete(UUID storyId, UUID userId) {
        }
    }
}
