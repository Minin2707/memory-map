package memory_map.backend.media.api;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.MultipartException;

import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;

class MediaMultipartExceptionHandlerTest {

    private final MediaMultipartExceptionHandler handler =
            new MediaMultipartExceptionHandler();

    @Test
    void shouldMapMultipartParserFailuresToSafeBadRequest() {
        ProblemDetail problem = handler.handleMultipartFailure();

        assertThat(problem.getStatus())
                .isEqualTo(HttpStatus.BAD_REQUEST.value());
        assertThat(problem.getTitle()).isEqualTo("Bad Request");
        assertThat(problem.getDetail()).isEqualTo("Invalid photo request");
        assertThat(problem.getInstance().toString())
                .isEqualTo("/api/v1/memories/media");
        assertThat(problem.toString())
                .doesNotContain("MaxUploadSizeExceededException")
                .doesNotContain("MultipartException")
                .doesNotContain("stackTrace");
    }

    @Test
    void shouldBindExpectedMultipartFailures() throws NoSuchMethodException {
        assertThat(exceptionTypes())
                .containsExactly(MultipartException.class);
        assertThat(MultipartException.class)
                .isAssignableFrom(MaxUploadSizeExceededException.class);
    }

    private static Class<?>[] exceptionTypes() throws NoSuchMethodException {
        return Arrays.stream(
                        MediaMultipartExceptionHandler.class
                                .getDeclaredMethods()
                )
                .filter(method -> method.getName().equals(
                        "handleMultipartFailure"
                ))
                .findFirst()
                .orElseThrow()
                .getAnnotation(ExceptionHandler.class)
                .value();
    }
}
