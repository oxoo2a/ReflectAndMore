package sa4e.reflect;

import java.util.ArrayList;
import java.util.List;

/** The hook that generated subclasses call before delegating to the original method. */
public final class Interceptor {

    public static final List<String> CALLS = new ArrayList<>();

    private Interceptor() {}

    public static void before(String method) {
        CALLS.add(method);
    }
}
