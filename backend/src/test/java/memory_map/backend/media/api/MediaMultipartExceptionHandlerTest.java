package memory_map.backend.media.api;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.MultipartException;

import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class MediaMultipartExceptionHandlerTest {

    private final MediaMultipartExceptionHandler handler =
            new MediaMultipartExceptionHandler();

    @Test
    void shouldMapMemoryPhotoMultipartFailuresToSafeBadRequest() {
        ProblemDetail problem = handle(
                "/api/v1/memories/00000000-0000-0000-0000-000000000001/media"
        );

        assertProblem(
                problem,
                "Invalid photo request",
                "/api/v1/memories/media"
        );
    }

    @Test
    void shouldMapAvatarMultipartFailuresToSafeBadRequest() {
        ProblemDetail problem = handle("/api/v1/me/avatar");

        assertProblem(
                problem,
                "Invalid avatar request",
                "/api/v1/me/avatar"
        );
    }

    @Test
    void shouldMapStoryCoverMultipartFailuresToSafeBadRequest() {
        ProblemDetail problem = handle(
                "/api/v1/stories/00000000-0000-0000-0000-000000000011/cover"
        );

        assertProblem(
                problem,
                "Invalid story cover request",
                "/api/v1/stories/cover"
        );
    }

    @Test
    void shouldMapMaxUploadSizeExceededThroughMultipartBoundary() {
        ProblemDetail problem = handler.handleMultipartFailure(
                new MaxUploadSizeExceededException(1024L),
                request("/api/v1/me/avatar")
        );

        assertProblem(
                problem,
                "Invalid avatar request",
                "/api/v1/me/avatar"
        );
    }

    @Test
    void shouldMapUnknownMultipartRoutesToGenericSafeBadRequest() {
        ProblemDetail problem = handle("/api/v1/other/upload");

        assertProblem(
                problem,
                "Invalid multipart request",
                "/api/v1/multipart"
        );
    }

    @Test
    void shouldNotClassifySimilarLookingOrMalformedPaths() {
        for (String path : List.of(
                "/api/v1/me/avatar/extra",
                "/api/v1/me/avatarish",
                "/api/v1/memories/not-a-uuid/media",
                "/api/v1/memories/00000000-0000-0000-0000-000000000001/media/extra",
                "/api/v1/stories/not-a-uuid/cover",
                "/api/v1/stories/00000000-0000-0000-0000-000000000011/cover/extra"
        )) {
            assertProblem(
                    handle(path),
                    "Invalid multipart request",
                    "/api/v1/multipart"
            );
        }
    }

    @Test
    void shouldNotExposeExceptionNamesStackTraceOrInternalData() {
        ProblemDetail problem = handler.handleMultipartFailure(
                new MultipartException(
                        "MaxUploadSizeExceededException stackTrace "
                                + "C:/private/path limit=1048576"
                ),
                request("/api/v1/other/upload")
        );

        assertThat(problem.toString())
                .doesNotContain("MaxUploadSizeExceededException")
                .doesNotContain("MultipartException")
                .doesNotContain("stackTrace")
                .doesNotContain("C:/private/path")
                .doesNotContain("1048576");
    }

    @Test
    void shouldBindExpectedMultipartFailures() throws NoSuchMethodException {
        assertThat(exceptionTypes())
                .containsExactly(MultipartException.class);
        assertThat(MultipartException.class)
                .isAssignableFrom(MaxUploadSizeExceededException.class);
    }

    private ProblemDetail handle(String path) {
        return handler.handleMultipartFailure(
                new MultipartException("parser failed"),
                request(path)
        );
    }

    private static MockHttpServletRequest request(String path) {
        return new MockHttpServletRequest("PUT", path);
    }

    private static void assertProblem(
            ProblemDetail problem,
            String detail,
            String instance
    ) {
        assertThat(problem.getStatus())
                .isEqualTo(HttpStatus.BAD_REQUEST.value());
        assertThat(problem.getTitle()).isEqualTo("Bad Request");
        assertThat(problem.getDetail()).isEqualTo(detail);
        assertThat(problem.getInstance().toString()).isEqualTo(instance);
        assertThat(problem.toString())
                .doesNotContain("MaxUploadSizeExceededException")
                .doesNotContain("MultipartException")
                .doesNotContain("stackTrace");
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
