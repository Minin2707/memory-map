package memory_map.backend.notification.api;

import memory_map.backend.notification.application.NotificationNotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.net.URI;

@RestControllerAdvice(assignableTypes = NotificationController.class)
public class NotificationApiExceptionHandler {

    private static final URI NOTIFICATION_NOT_FOUND_INSTANCE =
            URI.create("/api/v1/notifications");

    @ExceptionHandler(NotificationNotFoundException.class)
    public ProblemDetail handleNotificationNotFound() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                "Notification was not found"
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(NOTIFICATION_NOT_FOUND_INSTANCE);

        return problemDetail;
    }
}
