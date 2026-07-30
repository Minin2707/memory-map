package memory_map.backend.auth.refresh;

public interface RefreshTokenHasher {

    String hash(RawRefreshToken rawToken);

}
