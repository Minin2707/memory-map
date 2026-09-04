package memory_map.backend.invite.api;

import memory_map.backend.invite.application.InviteCreationUnavailableException;
import memory_map.backend.invite.application.InviteAcceptanceUnavailableException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.net.URI;

@RestControllerAdvice(assignableTypes = InviteController.class)
public class InviteApiExceptionHandler {

    private static final String INVITE_COULD_NOT_BE_CREATED =
            "Invite could not be created";
    private static final String INVITE_COULD_NOT_BE_ACCEPTED =
            "Invite could not be accepted";
    private static final String INVALID_INVITE_REQUEST =
            "Invalid invite request";
    private static final URI INVITE_COULD_NOT_BE_CREATED_INSTANCE =
            URI.create("/api/v1/stories/invites");
    private static final URI INVITE_COULD_NOT_BE_ACCEPTED_INSTANCE =
            URI.create("/api/v1/invites/accept");

    @ExceptionHandler(InviteCreationUnavailableException.class)
    public ProblemDetail handleInviteCreationUnavailable() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                INVITE_COULD_NOT_BE_CREATED
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(INVITE_COULD_NOT_BE_CREATED_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(InviteAcceptanceUnavailableException.class)
    public ProblemDetail handleInviteAcceptanceUnavailable() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                INVITE_COULD_NOT_BE_ACCEPTED
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(INVITE_COULD_NOT_BE_ACCEPTED_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler({
            MethodArgumentNotValidException.class,
            HttpMessageNotReadableException.class
    })
    public ProblemDetail handleBadRequest() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST,
                INVALID_INVITE_REQUEST
        );
        problemDetail.setTitle("Bad Request");
        problemDetail.setInstance(INVITE_COULD_NOT_BE_CREATED_INSTANCE);

        return problemDetail;
    }
}
