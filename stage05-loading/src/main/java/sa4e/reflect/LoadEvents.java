package sa4e.reflect;

import java.util.ArrayList;
import java.util.List;

/** Collects what static initializers report, so that Main can show when they ran. */
public final class LoadEvents {
    public static final List<String> EVENTS = new ArrayList<>();

    private LoadEvents() {}
}
