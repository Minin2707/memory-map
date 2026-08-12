package memory_map.backend.media.api;

import memory_map.backend.media.application.MediaDeletionUnavailableException;
import memory_map.backend.media.application.PhotoUploadUnavailableException;
import memory_map.backend.media.application.MediaUnavailableException;
import memory_map.backend.media.image.ImageProcessingException;
import memory_map.backend.media.image.InvalidImageException;
import memory_map.backend.media.storage.StorageException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;

import java.net.URI;

@RestControllerAdvice(assignableTypes = MediaController.class)
public class MediaApiExceptionHandler {

    private static final String PHOTO_COULD_NOT_BE_UPLOADED =
            "Photo could not be uploaded";
    private static final String INVALID_PHOTO_REQUEST =
            "Invalid photo request";
    private static final String PHOTO_UPLOAD_FAILED =
            "Photo upload failed";
    private static final URI MEDIA_INSTANCE =
            URI.create("/api/v1/memories/media");

    @ExceptionHandler(PhotoUploadUnavailableException.class)
    public ProblemDetail handlePhotoUploadUnavailable() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                PHOTO_COULD_NOT_BE_UPLOADED
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(MEDIA_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(MediaUnavailableException.class)
    public ProblemDetail handleMediaUnavailable() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                "Media could not be found"
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(MEDIA_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(MediaDeletionUnavailableException.class)
    public ProblemDetail handleMediaDeletionUnavailable() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                "Media could not be deleted"
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(MEDIA_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler({
            InvalidImageException.class,
            InvalidPhotoRequestException.class,
            MethodArgumentTypeMismatchException.class,
            MissingServletRequestPartException.class,
            HttpMediaTypeNotSupportedException.class
    })
    public ProblemDetail handleInvalidPhotoRequest() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST,
                INVALID_PHOTO_REQUEST
        );
        problemDetail.setTitle("Bad Request");
        problemDetail.setInstance(MEDIA_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler({
            ImageProcessingException.class,
            StorageException.class
    })
    public ProblemDetail handleTechnicalPhotoFailure() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.INTERNAL_SERVER_ERROR,
                PHOTO_UPLOAD_FAILED
        );
        problemDetail.setTitle("Internal Server Error");
        problemDetail.setInstance(MEDIA_INSTANCE);

        return problemDetail;
    }
}
