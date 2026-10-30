package sa4e.reflect;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Our first annotation: a free-text comment that a framework can read at run time.
 * <p>
 * {@code @Target} says where it may be written (the compiler enforces this),
 * {@code @Retention} says how long it survives: SOURCE (javac only), CLASS (in the class file,
 * invisible to reflection) or RUNTIME (readable through reflection).
 */
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.CONSTRUCTOR, ElementType.FIELD, ElementType.METHOD, ElementType.PARAMETER})
public @interface Comment {
    String value() default "";
}
