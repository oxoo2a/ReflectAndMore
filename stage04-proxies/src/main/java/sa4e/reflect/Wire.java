package sa4e.reflect;

import java.util.Map;

/**
 * A toy wire format: values are written as {@code type:text}. Real systems use XDR, IIOP,
 * Java serialization, JSON or Protocol Buffers; the idea is the same.
 */
public final class Wire {

    private static final Map<String, Class<?>> TYPES = Map.of(
            "int", int.class, "double", double.class, "boolean", boolean.class, "string", String.class);

    private Wire() {}

    public static String encode(Object value) {
        return switch (value) {
            case null -> "null";
            case Integer i -> "int:" + i;
            case Double d -> "double:" + d;
            case Boolean b -> "boolean:" + b;
            case String s -> "string:" + s;
            default -> throw new IllegalArgumentException("cannot marshal " + value.getClass().getName());
        };
    }

    public static Object decode(String text) {
        if (text.equals("null")) return null;
        int colon = text.indexOf(':');
        String type = text.substring(0, colon);
        String payload = text.substring(colon + 1);
        return switch (type) {
            case "int" -> Integer.parseInt(payload);
            case "double" -> Double.parseDouble(payload);
            case "boolean" -> Boolean.parseBoolean(payload);
            case "string" -> payload;
            default -> throw new IllegalArgumentException("unknown wire type " + type);
        };
    }

    public static String typeName(Class<?> type) {
        return type == String.class ? "string" : type.getName();
    }

    public static Class<?> type(String name) {
        Class<?> type = TYPES.get(name);
        if (type == null) throw new IllegalArgumentException("unknown parameter type " + name);
        return type;
    }
}
