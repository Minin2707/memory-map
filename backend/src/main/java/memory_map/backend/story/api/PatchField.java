package memory_map.backend.story.api;

public record PatchField<T>(

        boolean present,

        T value

) {
    public PatchField {
        if (!present && value != null) {
            throw new IllegalArgumentException(
                    "omitted field must not have a value"
            );
        }
    }

    public static <T> PatchField<T> omitted() {
        return new PatchField<>(false, null);
    }

    public static <T> PatchField<T> present(T value) {
        return new PatchField<>(true, value);
    }

    public boolean isPresent() {
        return present;
    }

    @Override
    public String toString() {
        if (present) {
            return "PatchField[present]";
        }

        return "PatchField[omitted]";
    }
}
