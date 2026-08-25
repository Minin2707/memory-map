package memory_map.backend.music.infrastructure.catalog;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ConfigurableApplicationContext;

import java.nio.file.Path;
import java.util.List;
import java.util.Objects;

public final class MusicCatalogImportRunner implements ApplicationRunner {

    private static final String MANIFEST_OPTION = "music.catalog.manifest";
    private static final String DRY_RUN_OPTION = "dry-run";
    private static final String DRY_RUN_PROPERTY_OPTION =
            "music.catalog.dry-run";

    private final MusicCatalogManifestLoader manifestLoader;
    private final MusicCatalogImportService importService;
    private final ConfigurableApplicationContext applicationContext;

    public MusicCatalogImportRunner(
            MusicCatalogManifestLoader manifestLoader,
            MusicCatalogImportService importService,
            ConfigurableApplicationContext applicationContext
    ) {
        this.manifestLoader = Objects.requireNonNull(
                manifestLoader,
                "manifestLoader must not be null"
        );
        this.importService = Objects.requireNonNull(
                importService,
                "importService must not be null"
        );
        this.applicationContext = Objects.requireNonNull(
                applicationContext,
                "applicationContext must not be null"
        );
    }

    @Override
    public void run(ApplicationArguments args) {
        Objects.requireNonNull(args, "args must not be null");

        Path manifestPath = manifestPath(args);
        boolean dryRun = dryRun(args);

        MusicCatalogManifest manifest = manifestLoader.load(manifestPath);
        MusicCatalogImportReport report = importService.importCatalog(
                manifest,
                dryRun
        );

        System.out.print(report.toOperatorText());
        SpringApplication.exit(applicationContext, () -> 0);
    }

    private static Path manifestPath(ApplicationArguments args) {
        List<String> values = args.getOptionValues(MANIFEST_OPTION);

        if (values == null || values.size() != 1 || values.get(0).isBlank()) {
            throw new MusicCatalogImportException(
                    "--" + MANIFEST_OPTION + " is required"
            );
        }

        return Path.of(values.get(0));
    }

    private static boolean dryRun(ApplicationArguments args) {
        if (args.containsOption(DRY_RUN_OPTION)) {
            return true;
        }

        List<String> values = args.getOptionValues(DRY_RUN_PROPERTY_OPTION);
        if (values == null || values.isEmpty()) {
            return false;
        }

        if (values.size() != 1) {
            throw new MusicCatalogImportException(
                    "--" + DRY_RUN_PROPERTY_OPTION
                            + " must be true or false"
            );
        }

        return Boolean.parseBoolean(values.get(0));
    }
}
