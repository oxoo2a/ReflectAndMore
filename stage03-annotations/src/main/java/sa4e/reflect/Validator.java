package sa4e.reflect;

import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;

/**
 * A generic validator: it knows nothing about the classes it checks. It walks the fields of any
 * object, looks for constraint annotations and reports violations. This is Jakarta Bean
 * Validation ({@code @NotNull}, {@code @Min}, {@code @Max}, ...) in 30 lines.
 */
public final class Validator {

    private Validator() {}

    public static List<String> validate(Object target) throws IllegalAccessException {
        List<String> violations = new ArrayList<>();
        for (Class<?> k = target.getClass(); k != null; k = k.getSuperclass()) {
            for (Field f : k.getDeclaredFields()) {
                if (Modifier.isStatic(f.getModifiers())) continue;
                f.setAccessible(true);
                Object value = f.get(target);

                if (f.isAnnotationPresent(NotNull.class) && value == null) {
                    violations.add(f.getName() + " must not be null");
                }
                Range range = f.getAnnotation(Range.class);
                if (range != null && value instanceof Number number) {
                    long v = number.longValue();
                    if (v < range.min() || v > range.max()) {
                        violations.add(f.getName() + " = " + v + " is outside [" + range.min() + ", " + range.max() + "]");
                    }
                }
            }
        }
        return violations;
    }
}
