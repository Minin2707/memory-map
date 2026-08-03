package memory_map.backend.invite.application;

import memory_map.backend.story.application.UserStory;

public interface AcceptInviteUseCase {

    UserStory acceptInvite(AcceptInviteCommand command);

}
