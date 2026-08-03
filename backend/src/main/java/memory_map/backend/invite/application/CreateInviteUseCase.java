package memory_map.backend.invite.application;

public interface CreateInviteUseCase {

    CreatedInvite createInvite(CreateInviteCommand command);

}
