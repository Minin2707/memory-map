package memory_map.backend.memory.application;

public record PatchField<T>(

        boolean provided,

        T value

) {
    public PatchField {
        if (!provided && value != null) {
            throw new IllegalArgumentException(
                    "not provided field must not have a value"
            );
        }
    }

    public static <T> PatchField<T> notProvided() {
        return new PatchField<>(false, null);
    }

    public static <T> PatchField<T> provided(T value) {
        return new PatchField<>(true, value);
    }

    public boolean isProvided() {
        return provided;
    }

    @Override
    public String toString() {
        if (provided) {
            return "PatchField[provided]";
        }

        return "PatchField[notProvided]";
    }
}
