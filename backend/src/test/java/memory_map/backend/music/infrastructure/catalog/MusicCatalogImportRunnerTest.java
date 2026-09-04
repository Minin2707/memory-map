package memory_map.backend.music.infrastructure.catalog;

import memory_map.backend.music.domain.MusicTrackStatus;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.boot.ExitCodeGenerator;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ConfigurableApplicationContext;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class MusicCatalogImportRunnerTest {

    private static final UUID TRACK_ID =
            UUID.fromString("00000000-0000-0000-0000-000000000001");

    private final MusicCatalogManifestLoader manifestLoader =
            mock(MusicCatalogManifestLoader.class);
    private final MusicCatalogImportService importService =
            mock(MusicCatalogImportService.class);
    private final ConfigurableApplicationContext applicationContext =
            mock(ConfigurableApplicationContext.class);

    @Test
    void shouldRejectNullManifestLoader() {
        assertThatThrownBy(() -> new MusicCatalogImportRunner(
                null,
                importService,
                applicationContext
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("manifestLoader must not be null");
    }

    @Test
    void shouldRejectNullImportService() {
        assertThatThrownBy(() -> new MusicCatalogImportRunner(
                manifestLoader,
                null,
                applicationContext
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("importService must not be null");
    }

    @Test
    void shouldRejectNullApplicationContext() {
        assertThatThrownBy(() -> new MusicCatalogImportRunner(
                manifestLoader,
                importService,
                null
        )).isInstanceOf(NullPointerException.class)
                .hasMessage("applicationContext must not be null");
    }

    @Test
    void shouldRejectNullApplicationArguments() {
        assertThatThrownBy(() -> runner().run(null))
                .isInstanceOf(NullPointerException.class)
                .hasMessage("args must not be null");

        verifyNoInteractions(manifestLoader, importService);
    }

    @Test
    void shouldRejectMissingManifestOption() {
        assertThatThrownBy(() -> runner().run(args("--dry-run")))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("--music.catalog.manifest is required");

        verifyNoInteractions(manifestLoader, importService);
    }

    @Test
    void shouldRejectManifestOptionWithoutUsableValue() {
        assertThatThrownBy(() -> runner().run(args("--music.catalog.manifest")))
                .isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("--music.catalog.manifest is required");

        verifyNoInteractions(manifestLoader, importService);
    }

    @Test
    void shouldRejectBlankManifestValue() {
        assertThatThrownBy(() -> runner().run(
                args("--music.catalog.manifest=   ")
        )).isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("--music.catalog.manifest is required");

        verifyNoInteractions(manifestLoader, importService);
    }

    @Test
    void shouldRejectMultipleManifestValues() {
        assertThatThrownBy(() -> runner().run(args(
                "--music.catalog.manifest=first.json",
                "--music.catalog.manifest=second.json"
        ))).isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("--music.catalog.manifest is required");

        verifyNoInteractions(manifestLoader, importService);
    }

    @Test
    void shouldPassValidManifestPathToLoader() {
        runSuccessfully("--music.catalog.manifest=catalog/manifest.json");

        verify(manifestLoader).load(Path.of("catalog/manifest.json"));
    }

    @Test
    void shouldImportWithDryRunFalseWhenDryRunOptionsAreMissing() {
        MusicCatalogManifest manifest = manifest();
        runSuccessfully(manifest, false, "--music.catalog.manifest=manifest.json");

        verify(importService).importCatalog(manifest, false);
    }

    @Test
    void shouldImportWithDryRunTrueWhenDryRunFlagIsPresent() {
        MusicCatalogManifest manifest = manifest();
        runSuccessfully(
                manifest,
                true,
                "--music.catalog.manifest=manifest.json",
                "--dry-run"
        );

        verify(importService).importCatalog(manifest, true);
    }

    @Test
    void shouldImportWithDryRunTrueWhenPropertyIsTrue() {
        MusicCatalogManifest manifest = manifest();
        runSuccessfully(
                manifest,
                true,
                "--music.catalog.manifest=manifest.json",
                "--music.catalog.dry-run=true"
        );

        verify(importService).importCatalog(manifest, true);
    }

    @Test
    void shouldImportWithDryRunFalseWhenPropertyIsFalse() {
        MusicCatalogManifest manifest = manifest();
        runSuccessfully(
                manifest,
                false,
                "--music.catalog.manifest=manifest.json",
                "--music.catalog.dry-run=false"
        );

        verify(importService).importCatalog(manifest, false);
    }

    @Test
    void shouldRejectMultipleDryRunPropertyValues() {
        assertThatThrownBy(() -> runner().run(args(
                "--music.catalog.manifest=manifest.json",
                "--music.catalog.dry-run=true",
                "--music.catalog.dry-run=false"
        ))).isInstanceOf(MusicCatalogImportException.class)
                .hasMessage("--music.catalog.dry-run must be true or false");

        verifyNoInteractions(manifestLoader, importService);
    }

    @Test
    void shouldPreferDryRunFlagOverDryRunProperty() {
        MusicCatalogManifest manifest = manifest();
        runSuccessfully(
                manifest,
                true,
                "--music.catalog.manifest=manifest.json",
                "--dry-run",
                "--music.catalog.dry-run=false"
        );

        verify(importService).importCatalog(manifest, true);
    }

    @Test
    void shouldRunSuccessfulFlowAndPrintOperatorReportAndExitApplication() {
        MusicCatalogManifest manifest = manifest();
        MusicCatalogImportReport report = report(false);
        when(manifestLoader.load(Path.of("manifest.json")))
                .thenReturn(manifest);
        when(importService.importCatalog(manifest, false)).thenReturn(report);

        ByteArrayOutputStream output = new ByteArrayOutputStream();
        PrintStream originalOut = System.out;
        try (PrintStream replacementOut = new PrintStream(
                output,
                true,
                StandardCharsets.UTF_8
        );
             MockedStatic<SpringApplication> springApplication =
                     mockStatic(SpringApplication.class)) {

            springApplication.when(() -> SpringApplication.exit(
                    eq(applicationContext),
                    any(ExitCodeGenerator.class)
            )).thenReturn(0);

            System.setOut(replacementOut);
            runner().run(args("--music.catalog.manifest=manifest.json"));

            verify(manifestLoader, times(1)).load(Path.of("manifest.json"));
            verify(importService, times(1)).importCatalog(manifest, false);
            springApplication.verify(() -> SpringApplication.exit(
                    eq(applicationContext),
                    any(ExitCodeGenerator.class)
            ));
            assertThat(output.toString(StandardCharsets.UTF_8))
                    .isEqualTo(report.toOperatorText());
        } finally {
            System.setOut(originalOut);
        }
    }

    private void runSuccessfully(String... arguments) {
        runSuccessfully(manifest(), false, arguments);
    }

    private void runSuccessfully(
            MusicCatalogManifest manifest,
            boolean expectedDryRun,
            String... arguments
    ) {
        when(manifestLoader.load(any(Path.class))).thenReturn(manifest);
        when(importService.importCatalog(manifest, expectedDryRun))
                .thenReturn(report(expectedDryRun));

        try (MockedStatic<SpringApplication> springApplication =
                     mockStatic(SpringApplication.class)) {
            springApplication.when(() -> SpringApplication.exit(
                    eq(applicationContext),
                    any(ExitCodeGenerator.class)
            )).thenReturn(0);

            runner().run(args(arguments));
        }
    }

    private MusicCatalogImportRunner runner() {
        return new MusicCatalogImportRunner(
                manifestLoader,
                importService,
                applicationContext
        );
    }

    private static ApplicationArguments args(String... arguments) {
        return new DefaultApplicationArguments(arguments);
    }

    private static MusicCatalogManifest manifest() {
        return new MusicCatalogManifest(List.of(new MusicCatalogManifestTrack(
                TRACK_ID,
                "Autumn Leaves",
                "Memory Story",
                180,
                10,
                Path.of("tracks/autumn-leaves.mp3"),
                "autumn-leaves.mp3",
                "music/catalog/autumn-leaves.mp3",
                "audio/mpeg",
                5L,
                "0000000000000000000000000000000000000000000000000000000000000000",
                MusicTrackStatus.ACTIVE,
                MusicCatalogLegalStatus.APPROVED
        )));
    }

    private static MusicCatalogImportReport report(boolean dryRun) {
        return new MusicCatalogImportReport(
                dryRun,
                List.of(new MusicCatalogTrackImportResult(
                        TRACK_ID,
                        "Autumn Leaves",
                        MusicTrackStatus.ACTIVE,
                        List.of(MusicCatalogImportAction.NO_OP),
                        "MATCHED",
                        dryRun ? "DRY_RUN" : "NO_OP"
                ))
        );
    }
}
