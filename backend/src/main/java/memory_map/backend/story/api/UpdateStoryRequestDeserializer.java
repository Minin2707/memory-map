package memory_map.backend.story.api;

import tools.jackson.core.JacksonException;
import tools.jackson.core.JsonParser;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ValueDeserializer;

public final class UpdateStoryRequestDeserializer
        extends ValueDeserializer<UpdateStoryRequest> {

    private static final String TITLE = "title";
    private static final String DESCRIPTION = "description";

    @Override
    public UpdateStoryRequest deserialize(
            JsonParser parser,
            DeserializationContext context
    ) throws JacksonException {
        JsonNode node = context.readTree(parser);

        if (!node.isObject()) {
            return context.reportInputMismatch(
                    UpdateStoryRequest.class,
                    "Update Story request must be a JSON object"
            );
        }

        try {
            return new UpdateStoryRequest(
                    field(node, TITLE),
                    field(node, DESCRIPTION)
            );
        } catch (IllegalArgumentException | NullPointerException exception) {
            return context.reportInputMismatch(
                    UpdateStoryRequest.class,
                    exception.getMessage()
            );
        }
    }

    private static PatchField<String> field(
            JsonNode node,
            String fieldName
    ) {
        JsonNode value = node.get(fieldName);

        if (value == null) {
            return PatchField.omitted();
        }

        if (value.isNull()) {
            return PatchField.<String>present(null);
        }

        if (!value.isString()) {
            throw new IllegalArgumentException(
                    fieldName + " must be a string or null"
            );
        }

        return PatchField.present(value.asString());
    }
}
