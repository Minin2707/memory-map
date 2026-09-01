package memory_map.backend.notification.application;

public final class NotificationNotFoundException extends RuntimeException {

    private static final String MESSAGE = "Notification was not found";

    public NotificationNotFoundException() {
        super(MESSAGE);
    }

    @Override
    public String toString() {
        return "NotificationNotFoundException[message=%s]"
                .formatted(getMessage());
    }
}
