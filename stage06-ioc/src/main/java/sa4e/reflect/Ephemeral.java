package sa4e.reflect;

/** A prototype-scoped component: every request yields a new instance. */
@Component
@Prototype
public final class Ephemeral {

    private static int counter;

    private final int number = ++counter;

    @Value("${ephemeral.prefix}")
    private String prefix;

    @Override
    public String toString() {
        return prefix + "#" + number;
    }
}
