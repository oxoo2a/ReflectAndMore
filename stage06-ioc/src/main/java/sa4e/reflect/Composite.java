package sa4e.reflect;

import java.util.ArrayList;
import java.util.List;

/**
 * A component that needs other components. It never creates them: the constructor receives
 * everything it depends on, which is "constructor injection", the recommended style. Note that
 * the class compiles and can be tested without any container.
 */
@Component
public final class Composite {

    private final Capability capability;
    private final Dependency dependency;
    private final int limit;
    private String state = "constructed, not yet initialized";
    private final List<String> received = new ArrayList<>();

    @Inject
    public Composite(@Named("candidate") Capability capability,
                     @Named("beta") Dependency dependency,
                     @Value("${composite.limit}") int limit) {
        this.capability = capability;
        this.dependency = dependency;
        this.limit = limit;
    }

    @PostConstruct
    void init() {
        state = "initialized with " + capability.getClass().getSimpleName() + ", " + dependency.name() + " and limit " + limit;
    }

    public String run() {
        capability.f(limit, 1.0);
        return "ran f(" + limit + ", 1.0) on " + capability;
    }

    @Subscribe
    void on(Event event) {
        received.add(event.name());
    }

    public List<String> received() {
        return received;
    }

    public String state() {
        return state;
    }
}
