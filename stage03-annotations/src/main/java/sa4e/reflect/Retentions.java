package sa4e.reflect;

import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;

/** Three annotations that differ only in retention, and a class that carries all three. */
public final class Retentions {

    @Retention(RetentionPolicy.SOURCE)
    public @interface SourceOnly {}

    @Retention(RetentionPolicy.CLASS)        // the default when @Retention is omitted
    public @interface ClassOnly {}

    @Retention(RetentionPolicy.RUNTIME)
    public @interface RuntimeOnly {}

    @SourceOnly
    @ClassOnly
    @RuntimeOnly
    public static final class Probe {}

    private Retentions() {}
}
