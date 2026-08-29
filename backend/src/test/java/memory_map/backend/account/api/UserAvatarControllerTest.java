package memory_map.backend.account.api;

import memory_map.backend.account.application.CurrentUserAvatarUseCase;
import memory_map.backend.account.application.DownloadCurrentUserAvatarCommand;
import memory_map.backend.account.application.DownloadedUserAvatar;
import memory_map.backend.account.application.RemoveCurrentUserAvatarCommand;
import memory_map.backend.account.application.UploadCurrentUserAvatarCommand;
import memory_map.backend.auth.domain.AuthenticatedUser;
import memory_map.backend.auth.security.CurrentAuthenticatedUserProvider;
import memory_map.backend.user.domain.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.util.TestPropertyValues;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.ApplicationContextInitializer;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.io.ByteArrayInputStream;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.asyncDispatch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(UserAvatarController.class)
@AutoConfigureMockMvc(addFilters = false)
@ContextConfiguration(
        initializers = UserAvatarControllerTest.MinioEnabledInitializer.class,
        classes = {
                UserAvatarController.class,
                AccountApiExceptionHandler.class,
                UserAvatarControllerTest.UserAvatarControllerTestConfiguration.class
        }
)
class UserAvatarControllerTest {

    private static final UUID USER_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final Instant CURRENT_TIME =
            Instant.parse("2026-01-10T10:00:00Z");
    private static final byte[] JPEG_BYTES =
            new byte[] {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private FakeCurrentUserAvatarUseCase avatarUseCase;

    @Autowired
    private FakeCurrentAuthenticatedUserProvider
            currentAuthenticatedUserProvider;

    @BeforeEach
    void resetFakes() {
        avatarUseCase.reset();
        currentAuthenticatedUserProvider.reset();
    }

    @Test
    void shouldUploadCurrentUserAvatarAndReturnSafeUser() throws Exception {
        mockMvc.perform(multipart("/api/v1/me/avatar")
                        .file(file("avatar.jpg", "image/jpeg", JPEG_BYTES))
                        .with(request -> {
                            request.setMethod("PUT");
                            return request;
                        })
                        .param("userId", UUID.randomUUID().toString())
                        .param("storageKey", "attacker-key"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(USER_ID.toString()))
                .andExpect(jsonPath("$.displayName").value("Ada Lovelace"))
                .andExpect(jsonPath("$.avatarUrl")
                        .value("/api/v1/me/avatar/1768039200000"))
                .andExpect(jsonPath("$.hasCustomAvatar").value(true))
                .andExpect(jsonPath("$.storageKey").doesNotExist())
                .andExpect(jsonPath("$.customAvatarStorageKey").doesNotExist());

        UploadCurrentUserAvatarCommand command =
                avatarUseCase.receivedUploadCommand();

        assertThat(currentAuthenticatedUserProvider.callCount())
                .isEqualTo(1);
        assertThat(command.authenticatedUser())
                .isEqualTo(new AuthenticatedUser(USER_ID));
        assertThat(command.avatarObjectId()).isNotNull();
        assertThat(command.currentTime()).isEqualTo(CURRENT_TIME);
        assertThat(command.image().content()).containsExactly(JPEG_BYTES);
        assertThat(command.image().declaredContentType())
                .isEqualTo("image/jpeg");
    }

    @Test
    void shouldDownloadCurrentUserAvatarWithPrivateHeaders() throws Exception {
        MvcResult result = mockMvc.perform(get("/api/v1/me/avatar/1"))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(result))
                .andExpect(status().isOk())
                .andExpect(content().bytes(new byte[] {1, 2, 3}))
                .andExpect(content().contentTypeCompatibleWith("image/jpeg"))
                .andExpect(header().string(
                        "Cache-Control",
                        "private, no-store"
                ));

        assertThat(avatarUseCase.receivedDownloadCommand())
                .isEqualTo(new DownloadCurrentUserAvatarCommand(
                        new AuthenticatedUser(USER_ID)
                ));
    }

    @Test
    void shouldRemoveCurrentUserAvatarAndFallbackToGoogleAvatar()
            throws Exception {
        mockMvc.perform(delete("/api/v1/me/avatar"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.avatarUrl")
                        .value("https://example.com/google.png"))
                .andExpect(jsonPath("$.hasCustomAvatar").value(false));

        assertThat(avatarUseCase.receivedRemoveCommand())
                .isEqualTo(new RemoveCurrentUserAvatarCommand(
                        new AuthenticatedUser(USER_ID),
                        CURRENT_TIME
                ));
    }

    private static MockMultipartFile file(
            String name,
            String contentType,
            byte[] content
    ) {
        return new MockMultipartFile(
                "file",
                name,
                contentType,
                content
        );
    }

    static final class MinioEnabledInitializer
            implements ApplicationContextInitializer
            <ConfigurableApplicationContext> {

        @Override
        public void initialize(ConfigurableApplicationContext context) {
            TestPropertyValues
                    .of("app.storage.minio.enabled=true")
                    .applyTo(context);
        }
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class UserAvatarControllerTestConfiguration {

        @Bean
        Clock clock() {
            return Clock.fixed(CURRENT_TIME, ZoneOffset.UTC);
        }

        @Bean
        FakeCurrentUserAvatarUseCase avatarUseCase() {
            return new FakeCurrentUserAvatarUseCase();
        }

        @Bean
        FakeCurrentAuthenticatedUserProvider
        currentAuthenticatedUserProvider() {
            return new FakeCurrentAuthenticatedUserProvider();
        }
    }

    static final class FakeCurrentUserAvatarUseCase
            implements CurrentUserAvatarUseCase {

        private UploadCurrentUserAvatarCommand receivedUploadCommand;
        private DownloadCurrentUserAvatarCommand receivedDownloadCommand;
        private RemoveCurrentUserAvatarCommand receivedRemoveCommand;

        @Override
        public User uploadAvatar(UploadCurrentUserAvatarCommand command) {
            receivedUploadCommand = command;
            return userWithCustomAvatar();
        }

        @Override
        public DownloadedUserAvatar downloadAvatar(
                DownloadCurrentUserAvatarCommand command
        ) {
            receivedDownloadCommand = command;
            return new DownloadedUserAvatar(
                    new ByteArrayInputStream(new byte[] {1, 2, 3}),
                    3,
                    "image/jpeg"
            );
        }

        @Override
        public User removeAvatar(RemoveCurrentUserAvatarCommand command) {
            receivedRemoveCommand = command;
            return userWithGoogleAvatar();
        }

        private UploadCurrentUserAvatarCommand receivedUploadCommand() {
            return receivedUploadCommand;
        }

        private DownloadCurrentUserAvatarCommand receivedDownloadCommand() {
            return receivedDownloadCommand;
        }

        private RemoveCurrentUserAvatarCommand receivedRemoveCommand() {
            return receivedRemoveCommand;
        }

        private void reset() {
            receivedUploadCommand = null;
            receivedDownloadCommand = null;
            receivedRemoveCommand = null;
        }

        private User userWithCustomAvatar() {
            return new User(
                    USER_ID,
                    "google-subject-123",
                    "Ada Lovelace",
                    "https://example.com/google.png",
                    "users/%s/avatar/avatar-object".formatted(USER_ID),
                    CURRENT_TIME,
                    CURRENT_TIME,
                    CURRENT_TIME,
                    null
            );
        }

        private User userWithGoogleAvatar() {
            return new User(
                    USER_ID,
                    "google-subject-123",
                    "Ada Lovelace",
                    "https://example.com/google.png",
                    CURRENT_TIME,
                    CURRENT_TIME
            );
        }
    }

    static final class FakeCurrentAuthenticatedUserProvider
            implements CurrentAuthenticatedUserProvider {

        private int callCount;

        @Override
        public AuthenticatedUser getCurrentUser() {
            callCount++;
            return new AuthenticatedUser(USER_ID);
        }

        private int callCount() {
            return callCount;
        }

        private void reset() {
            callCount = 0;
        }
    }
}
