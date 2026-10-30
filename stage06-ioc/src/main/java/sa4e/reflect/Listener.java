package sa4e.reflect;

import java.util.ArrayList;
import java.util.List;

/** Subscribes to everything: the parameter type Object matches every event. */
@Component
public final class Listener {

    private final List<String> seen = new ArrayList<>();

    @Subscribe
    void onAnything(Object event) {
        seen.add(event.getClass().getSimpleName() + " " + event);
    }

    public List<String> seen() {
        return seen;
    }
}
