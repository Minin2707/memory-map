package memory_map.backend.music.infrastructure.catalog;

public class MusicCatalogImportException extends RuntimeException {

    public MusicCatalogImportException(String message) {
        super(message);
    }

    public MusicCatalogImportException(String message, Throwable cause) {
        super(message, cause);
    }
}
