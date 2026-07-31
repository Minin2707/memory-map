package memory_map.backend.story.application;

import memory_map.backend.auth.domain.AuthenticatedUser;

import java.util.List;

public interface GetStoriesUseCase {

    List<UserStory> getStories(AuthenticatedUser authenticatedUser);

}
