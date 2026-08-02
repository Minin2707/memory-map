package memory_map.backend.story.application;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UpdateStoryFieldTest {

    @Test
    void shouldRepresentNotProvidedField() {

        UpdateStoryField<String> field = UpdateStoryField.notProvided();

        assertThat(field.isProvided()).isFalse();
        assertThat(field.provided()).isFalse();
        assertThat(field.value()).isNull();
        assertThat(field.toString())
                .isEqualTo("UpdateStoryField[notProvided]");
    }

    @Test
    void shouldRepresentProvidedNonNullField() {

        UpdateStoryField<String> field =
                UpdateStoryField.provided("Our Story");

        assertThat(field.isProvided()).isTrue();
        assertThat(field.provided()).isTrue();
        assertThat(field.value()).isEqualTo("Our Story");
        assertThat(field.toString())
                .isEqualTo("UpdateStoryField[provided]");
    }

    @Test
    void shouldRepresentProvidedNullField() {

        UpdateStoryField<String> field =
                UpdateStoryField.<String>provided(null);

        assertThat(field.isProvided()).isTrue();
        assertThat(field.provided()).isTrue();
        assertThat(field.value()).isNull();
        assertThat(field.toString())
                .isEqualTo("UpdateStoryField[provided]");
    }

    @Test
    void shouldRejectNotProvidedFieldWithValue() {

        assertThatThrownBy(() -> new UpdateStoryField<>(false, "value"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("not provided field must not have a value");
    }

    @Test
    void shouldPreserveValueSemantics() {

        UpdateStoryField<String> first =
                UpdateStoryField.provided("Our Story");
        UpdateStoryField<String> second =
                UpdateStoryField.provided("Our Story");
        UpdateStoryField<String> different =
                UpdateStoryField.notProvided();

        assertThat(first).isEqualTo(second);
        assertThat(first).isNotEqualTo(different);
        assertThat(first.hashCode()).isEqualTo(second.hashCode());
    }
}
