package memory_map.backend.account.application;

import memory_map.backend.user.domain.User;
import memory_map.backend.user.repository.UserRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Objects;

public class TransactionalCurrentUserProfileService
        implements UpdateCurrentUserDisplayNameUseCase {

    public static final int DISPLAY_NAME_MAX_LENGTH = 255;

    private final UserRepository userRepository;

    public TransactionalCurrentUserProfileService(
            UserRepository userRepository
    ) {
        this.userRepository = Objects.requireNonNull(
                userRepository,
                "userRepository must not be null"
        );
    }

    @Override
    @Transactional
    public User updateDisplayName(
            UpdateCurrentUserDisplayNameCommand command
    ) {
        Objects.requireNonNull(command, "command must not be null");

        String displayName = normalizeDisplayName(command.displayName());
        userRepository.findActiveByIdForUpdate(
                        command.authenticatedUser().userId()
                )
                .orElseThrow(CurrentUserProfileUnavailableException::new);

        return userRepository.updateDisplayName(
                command.authenticatedUser().userId(),
                displayName,
                command.currentTime()
        );
    }

    private static String normalizeDisplayName(String displayName) {
        String normalized = displayName.trim();

        if (normalized.isBlank() ||
                normalized.length() > DISPLAY_NAME_MAX_LENGTH ||
                containsControlCharacter(normalized)) {
            throw new InvalidDisplayNameException();
        }

        return normalized;
    }

    private static boolean containsControlCharacter(String value) {
        return value.chars().anyMatch(Character::isISOControl);
    }
}
