package memory_map.backend.memory.application;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PatchFieldTest {

    @Test
    void shouldRepresentNotProvidedField() {

        PatchField<String> field = PatchField.notProvided();

        assertThat(field.isProvided()).isFalse();
        assertThat(field.provided()).isFalse();
        assertThat(field.value()).isNull();
        assertThat(field.toString())
                .isEqualTo("PatchField[notProvided]");
    }

    @Test
    void shouldRepresentProvidedNonNullField() {

        PatchField<String> field = PatchField.provided("Secret value");

        assertThat(field.isProvided()).isTrue();
        assertThat(field.provided()).isTrue();
        assertThat(field.value()).isEqualTo("Secret value");
        assertThat(field.toString())
                .isEqualTo("PatchField[provided]")
                .doesNotContain("Secret value");
    }

    @Test
    void shouldRepresentProvidedNullField() {

        PatchField<String> field = PatchField.provided(null);

        assertThat(field.isProvided()).isTrue();
        assertThat(field.provided()).isTrue();
        assertThat(field.value()).isNull();
        assertThat(field.toString())
                .isEqualTo("PatchField[provided]");
    }

    @Test
    void shouldRejectNotProvidedFieldWithValue() {

        assertThatThrownBy(() -> new PatchField<>(false, "value"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("not provided field must not have a value");
    }

    @Test
    void shouldPreserveValueSemantics() {

        PatchField<String> first = PatchField.provided("value");
        PatchField<String> second = PatchField.provided("value");
        PatchField<String> differentValue = PatchField.provided("other");
        PatchField<String> differentState = PatchField.notProvided();

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(differentValue);
        assertThat(first).isNotEqualTo(differentState);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }

    @Test
    void shouldSupportDifferentValueTypes() {

        PatchField<Double> latitude = PatchField.provided(41.715137);
        PatchField<LocalDate> eventDate =
                PatchField.provided(LocalDate.of(2024, 5, 18));

        assertThat(latitude.value()).isEqualTo(41.715137);
        assertThat(eventDate.value()).isEqualTo(LocalDate.of(2024, 5, 18));
        assertThat(latitude.toString())
                .doesNotContain("41.715137");
        assertThat(eventDate.toString())
                .doesNotContain("2024-05-18");
    }
}
