package memory_map.backend.auth.api;

import memory_map.backend.auth.google.GoogleIdentityVerificationException;
import memory_map.backend.auth.refresh.InvalidRefreshTokenException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class AuthApiExceptionHandler {

    private static final String AUTHENTICATION_FAILED =
            "Authentication failed";

    @ExceptionHandler({
            GoogleIdentityVerificationException.class,
            InvalidRefreshTokenException.class
    })
    public ProblemDetail handleAuthenticationFailure() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.UNAUTHORIZED,
                AUTHENTICATION_FAILED
        );
        problemDetail.setTitle("Unauthorized");

        return problemDetail;
    }
}
