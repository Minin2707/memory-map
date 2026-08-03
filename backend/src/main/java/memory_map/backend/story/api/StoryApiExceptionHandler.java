package memory_map.backend.story.api;

import memory_map.backend.story.application.LastStoryOwnerCannotLeaveException;
import memory_map.backend.story.application.ParticipantCannotRemoveSelfException;
import memory_map.backend.story.application.StoryNotFoundException;
import memory_map.backend.story.application.StoryOwnerCannotBeRemovedException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.net.URI;

@RestControllerAdvice(assignableTypes = {
        StoryController.class,
        StoryParticipantController.class
})
public class StoryApiExceptionHandler {

    private static final String STORY_NOT_FOUND = "Story was not found";
    private static final URI STORY_NOT_FOUND_INSTANCE =
            URI.create("/api/v1/stories");
    private static final URI LEAVE_STORY_INSTANCE =
            URI.create("/api/v1/stories/participants/me");
    private static final URI REMOVE_PARTICIPANT_INSTANCE =
            URI.create("/api/v1/stories/participants");

    @ExceptionHandler(StoryNotFoundException.class)
    public ProblemDetail handleStoryNotFound() {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                STORY_NOT_FOUND
        );
        problemDetail.setTitle("Not Found");
        problemDetail.setInstance(STORY_NOT_FOUND_INSTANCE);

        return problemDetail;
    }

    @ExceptionHandler(LastStoryOwnerCannotLeaveException.class)
    public ProblemDetail handleLastStoryOwnerCannotLeave(
            LastStoryOwnerCannotLeaveException exception
    ) {
        return conflictProblem(exception.getMessage(), LEAVE_STORY_INSTANCE);
    }

    @ExceptionHandler({
            ParticipantCannotRemoveSelfException.class,
            StoryOwnerCannotBeRemovedException.class
    })
    public ProblemDetail handleRemoveParticipantConflict(
            RuntimeException exception
    ) {
        return conflictProblem(
                exception.getMessage(),
                REMOVE_PARTICIPANT_INSTANCE
        );
    }

    private static ProblemDetail conflictProblem(
            String detail,
            URI instance
    ) {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.CONFLICT,
                detail
        );
        problemDetail.setTitle("Conflict");
        problemDetail.setInstance(instance);

        return problemDetail;
    }
}
