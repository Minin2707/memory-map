package memory_map.backend.account.application;

import memory_map.backend.user.domain.User;

public interface UpdateCurrentUserDisplayNameUseCase {

    User updateDisplayName(UpdateCurrentUserDisplayNameCommand command);
}
