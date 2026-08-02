package memory_map.backend.story.application;

public record UpdateStoryField<T>(

        boolean provided,

        T value

) {
    public UpdateStoryField {
        if (!provided && value != null) {
            throw new IllegalArgumentException(
                    "not provided field must not have a value"
            );
        }
    }

    public static <T> UpdateStoryField<T> notProvided() {
        return new UpdateStoryField<>(false, null);
    }

    public static <T> UpdateStoryField<T> provided(T value) {
        return new UpdateStoryField<>(true, value);
    }

    public boolean isProvided() {
        return provided;
    }

    @Override
    public String toString() {
        if (provided) {
            return "UpdateStoryField[provided]";
        }

        return "UpdateStoryField[notProvided]";
    }
}
