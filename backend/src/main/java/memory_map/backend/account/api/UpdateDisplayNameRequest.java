package memory_map.backend.account.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import memory_map.backend.account.application.TransactionalCurrentUserProfileService;

public record UpdateDisplayNameRequest(

        @NotBlank
        @Size(max = TransactionalCurrentUserProfileService.DISPLAY_NAME_MAX_LENGTH)
        String displayName

) {
}
