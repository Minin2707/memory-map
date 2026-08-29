package memory_map.backend.account.application;

public class CurrentUserProfileUnavailableException extends RuntimeException {

    public CurrentUserProfileUnavailableException() {
        super("Current user profile is unavailable");
    }
}
