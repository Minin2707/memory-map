package memory_map.backend.account.api;

import memory_map.backend.account.application.AccountDeletionOwnershipConflictException;
import memory_map.backend.account.application.AccountDeletionUnavailableException;
import memory_map.backend.account.application.CurrentUserProfileUnavailableException;
import memory_map.backend.account.application.InvalidDisplayNameException;
import memory_map.backend.account.application.InvalidUserAvatarException;
import memory_map.backend.account.application.UserAvatarUnavailableException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.net.URI;

@RestControllerAdvice(assignableTypes = {
        AccountController.class,
        UserAvatarController.class
})
public class AccountApiExceptionHandler {

    private static final URI ACCOUNT_DELETION_INSTANCE =
            URI.create("/api/v1/me");
    private static final URI ACCOUNT_AVATAR_INSTANCE =
            URI.create("/api/v1/me/avatar");
    private static final URI DISPLAY_NAME_INSTANCE =
            URI.create("/api/v1/me/display-name");

    @ExceptionHandler(AccountDeletionOwnershipConflictException.class)
    public ProblemDetail handleOwnershipConflict(
            AccountDeletionOwnershipConflictException exception
    ) {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.CONFLICT,
                exception.getMessage()
        );
        problemDetail.setTitle("Conflict");
        problemDetail.setInstance(ACCOUNT_DELETION_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(AccountDeletionUnavailableException.class)
    public ProblemDetail handleDeletionUnavailable() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.CONFLICT,
                "Profile could not be deleted"
        );
        problemDetail.setTitle("Conflict");
        problemDetail.setInstance(ACCOUNT_DELETION_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler({
            MethodArgumentNotValidException.class,
            InvalidDisplayNameException.class
    })
    public ProblemDetail handleInvalidDisplayName() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST,
                "Invalid display name"
        );
        problemDetail.setTitle("Bad Request");
        problemDetail.setInstance(DISPLAY_NAME_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(CurrentUserProfileUnavailableException.class)
    public ProblemDetail handleCurrentUserProfileUnavailable() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                "Current user profile is unavailable"
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(DISPLAY_NAME_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler({
            InvalidAvatarRequestException.class,
            InvalidUserAvatarException.class
    })
    public ProblemDetail handleInvalidAvatarRequest() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST,
                "Invalid avatar request"
        );
        problemDetail.setTitle("Bad Request");
        problemDetail.setInstance(ACCOUNT_AVATAR_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(UserAvatarUnavailableException.class)
    public ProblemDetail handleAvatarUnavailable() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                "Avatar is unavailable"
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(ACCOUNT_AVATAR_INSTANCE);

        return problemDetail;
    }
}
