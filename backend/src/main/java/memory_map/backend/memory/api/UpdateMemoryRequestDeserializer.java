package memory_map.backend.memory.api;

import memory_map.backend.story.api.PatchField;
import tools.jackson.core.JacksonException;
import tools.jackson.core.JsonParser;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ValueDeserializer;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;

public final class UpdateMemoryRequestDeserializer
        extends ValueDeserializer<UpdateMemoryRequest> {

    private static final String TITLE = "title";
    private static final String DESCRIPTION = "description";
    private static final String PLACE_NAME = "placeName";
    private static final String LATITUDE = "latitude";
    private static final String LONGITUDE = "longitude";
    private static final String EVENT_DATE = "eventDate";

    @Override
    public UpdateMemoryRequest deserialize(
            JsonParser parser,
            DeserializationContext context
    ) throws JacksonException {
        JsonNode node = context.readTree(parser);

        if (!node.isObject()) {
            return context.reportInputMismatch(
                    UpdateMemoryRequest.class,
                    "Update Memory request must be a JSON object"
            );
        }

        try {
            return new UpdateMemoryRequest(
                    stringField(node, TITLE),
                    stringField(node, DESCRIPTION),
                    stringField(node, PLACE_NAME),
                    doubleField(node, LATITUDE),
                    doubleField(node, LONGITUDE),
                    dateField(node, EVENT_DATE)
            );
        } catch (IllegalArgumentException | NullPointerException exception) {
            return context.reportInputMismatch(
                    UpdateMemoryRequest.class,
                    exception.getMessage()
            );
        }
    }

    private static PatchField<String> stringField(
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

    private static PatchField<Double> doubleField(
            JsonNode node,
            String fieldName
    ) {
        JsonNode value = node.get(fieldName);

        if (value == null) {
            return PatchField.omitted();
        }

        if (value.isNull()) {
            return PatchField.<Double>present(null);
        }

        if (!value.isNumber()) {
            throw new IllegalArgumentException(
                    fieldName + " must be a number or null"
            );
        }

        return PatchField.present(value.asDouble());
    }

    private static PatchField<LocalDate> dateField(
            JsonNode node,
            String fieldName
    ) {
        JsonNode value = node.get(fieldName);

        if (value == null) {
            return PatchField.omitted();
        }

        if (value.isNull()) {
            return PatchField.<LocalDate>present(null);
        }

        if (!value.isString()) {
            throw new IllegalArgumentException(
                    fieldName + " must be a date string or null"
            );
        }

        try {
            return PatchField.present(LocalDate.parse(value.asString()));
        } catch (DateTimeParseException exception) {
            throw new IllegalArgumentException(
                    fieldName + " must be a valid date",
                    exception
            );
        }
    }
}
