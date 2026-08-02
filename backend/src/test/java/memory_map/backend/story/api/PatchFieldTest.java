package memory_map.backend.story.api;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PatchFieldTest {

    @Test
    void shouldRepresentOmittedField() {

        PatchField<String> field = PatchField.omitted();

        assertThat(field.isPresent()).isFalse();
        assertThat(field.present()).isFalse();
        assertThat(field.value()).isNull();
        assertThat(field.toString()).isEqualTo("PatchField[omitted]");
    }

    @Test
    void shouldRepresentPresentValue() {

        PatchField<String> field = PatchField.present("value");

        assertThat(field.isPresent()).isTrue();
        assertThat(field.present()).isTrue();
        assertThat(field.value()).isEqualTo("value");
        assertThat(field.toString()).isEqualTo("PatchField[present]");
    }

    @Test
    void shouldRepresentPresentNull() {

        PatchField<String> field = PatchField.<String>present(null);

        assertThat(field.isPresent()).isTrue();
        assertThat(field.present()).isTrue();
        assertThat(field.value()).isNull();
        assertThat(field.toString()).isEqualTo("PatchField[present]");
    }

    @Test
    void shouldRejectOmittedFieldWithValue() {

        assertThatThrownBy(() -> new PatchField<>(false, "value"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("omitted field must not have a value");
    }

    @Test
    void shouldPreserveValueSemantics() {

        PatchField<String> first = PatchField.present("value");
        PatchField<String> second = PatchField.present("value");
        PatchField<String> different = PatchField.omitted();

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }
}
