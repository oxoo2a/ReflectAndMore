package sa4e.reflect;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/** Declarative constraint for numbers, checked by {@link Validator}. Members may have defaults. */
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.FIELD, ElementType.PARAMETER})
public @interface Range {
    long min() default Long.MIN_VALUE;

    long max() default Long.MAX_VALUE;
}
