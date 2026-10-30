package sa4e.reflect;

import java.lang.annotation.ElementType;
import java.lang.annotation.Repeatable;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * A repeatable annotation. Writing {@code @Tag("a") @Tag("b")} is syntactic sugar: the compiler
 * wraps the repeats into one {@code @Tag.List({@Tag("a"), @Tag("b")})}, the container type named
 * in {@code @Repeatable}.
 */
@Repeatable(Tag.List.class)
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.METHOD})
public @interface Tag {
    String value();

    @Retention(RetentionPolicy.RUNTIME)
    @Target({ElementType.TYPE, ElementType.METHOD})
    @interface List {
        Tag[] value();
    }
}
