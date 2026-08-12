package memory_map.backend.media.api;

import memory_map.backend.media.application.MediaDeletionUnavailableException;
import memory_map.backend.media.application.MediaUnavailableException;
import memory_map.backend.media.application.PhotoUploadUnavailableException;
import memory_map.backend.media.image.ImageProcessingException;
import memory_map.backend.media.image.InvalidImageException;
import memory_map.backend.media.storage.StorageException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;

class MediaApiExceptionHandlerTest {

    private final MediaApiExceptionHandler handler =
            new MediaApiExceptionHandler();

    @Test
    void shouldMapUnavailableToSafeNotFound() {
        ProblemDetail problem = handler.handlePhotoUploadUnavailable();

        assertThat(problem.getStatus()).isEqualTo(HttpStatus.NOT_FOUND.value());
        assertThat(problem.getTitle()).isEqualTo("Not Found");
        assertThat(problem.getDetail())
                .isEqualTo("Photo could not be uploaded");
        assertThat(problem.getInstance().toString())
                .isEqualTo("/api/v1/memories/media");
    }

    @Test
    void shouldMapMediaUnavailableToSafeNotFound() {
        ProblemDetail problem = handler.handleMediaUnavailable();

        assertThat(problem.getStatus()).isEqualTo(HttpStatus.NOT_FOUND.value());
        assertThat(problem.getTitle()).isEqualTo("Not Found");
        assertThat(problem.getDetail()).isEqualTo("Media could not be found");
        assertThat(problem.toString())
                .doesNotContain("StorageKey")
                .doesNotContain("bucket")
                .doesNotContain("MinIO")
                .doesNotContain("media/");
    }

    @Test
    void shouldMapMediaDeletionUnavailableToSafeNotFound() {
        ProblemDetail problem = handler.handleMediaDeletionUnavailable();

        assertThat(problem.getStatus()).isEqualTo(HttpStatus.NOT_FOUND.value());
        assertThat(problem.getTitle()).isEqualTo("Not Found");
        assertThat(problem.getDetail())
                .isEqualTo("Media could not be deleted");
        assertThat(problem.toString())
                .doesNotContain("StorageKey")
                .doesNotContain("bucket")
                .doesNotContain("MinIO")
                .doesNotContain("media/");
    }


    @Test
    void shouldMapInvalidPhotoRequestToSafeBadRequest() {
        ProblemDetail problem = handler.handleInvalidPhotoRequest();

        assertThat(problem.getStatus())
                .isEqualTo(HttpStatus.BAD_REQUEST.value());
        assertThat(problem.getTitle()).isEqualTo("Bad Request");
        assertThat(problem.getDetail()).isEqualTo("Invalid photo request");
        assertThat(problem.toString())
                .doesNotContain("MIME_MISMATCH")
                .doesNotContain("MaxUploadSizeExceededException")
                .doesNotContain("Multipart")
                .doesNotContain("stackTrace");
    }

    @Test
    void shouldMapTechnicalFailuresToSafeInternalServerError() {
        ProblemDetail problem = handler.handleTechnicalPhotoFailure();

        assertThat(problem.getStatus())
                .isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR.value());
        assertThat(problem.getTitle()).isEqualTo("Internal Server Error");
        assertThat(problem.getDetail()).isEqualTo("Photo upload failed");
        assertThat(problem.toString())
                .doesNotContain("StorageException")
                .doesNotContain("ImageProcessingException")
                .doesNotContain("MinIO")
                .doesNotContain("stackTrace");
    }

    @Test
    void shouldBindExpectedFailuresToSafeHandlers() throws NoSuchMethodException {
        assertThat(exceptionTypes("handlePhotoUploadUnavailable"))
                .containsExactly(PhotoUploadUnavailableException.class);
        assertThat(exceptionTypes("handleMediaUnavailable"))
                .containsExactly(MediaUnavailableException.class);
        assertThat(exceptionTypes("handleMediaDeletionUnavailable"))
                .containsExactly(MediaDeletionUnavailableException.class);
        assertThat(exceptionTypes("handleInvalidPhotoRequest"))
                .contains(
                        InvalidImageException.class,
                        InvalidPhotoRequestException.class,
                        MethodArgumentTypeMismatchException.class
                );
        assertThat(exceptionTypes("handleTechnicalPhotoFailure"))
                .containsExactly(
                        ImageProcessingException.class,
                        StorageException.class
                );
    }

    private static Class<?>[] exceptionTypes(String methodName)
            throws NoSuchMethodException {

        return Arrays.stream(MediaApiExceptionHandler.class.getDeclaredMethods())
                .filter(method -> method.getName().equals(methodName))
                .findFirst()
                .orElseThrow()
                .getAnnotation(ExceptionHandler.class)
                .value();
    }
}
