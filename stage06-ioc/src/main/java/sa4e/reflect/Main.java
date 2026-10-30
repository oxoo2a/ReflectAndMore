package sa4e.reflect;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;

/**
 * Stage 06: inversion of control and dependency injection.
 * <p>
 * Until now Main created every object and wired it to its collaborators. Now a container does
 * that: it finds the components, creates them in dependency order, injects what they declare
 * they need, fills configuration values and calls lifecycle methods. The components call
 * nothing of this; they are called. "Don't call us, we'll call you."
 */
public final class Main {

    /** The service-locator alternative: a global registry that components pull from. */
    static final class Locator {
        private static final Map<Class<?>, Object> REGISTRY = new HashMap<>();

        static <T> void put(Class<T> type, T instance) {
            REGISTRY.put(type, instance);
        }

        static <T> T get(Class<T> type) {
            Object o = REGISTRY.get(type);
            if (o == null) throw new IllegalStateException("nothing registered for " + type.getSimpleName());
            return type.cast(o);
        }
    }

    /** A class that hides its dependency behind the locator. */
    static final class LocatorUser {
        private final Dependency dependency = Locator.get(Dependency.class);   // invisible from the outside

        String describe() {
            return "using " + dependency.name();
        }
    }

    public static void main(String[] args) throws Exception {
        Report r = Report.stdout();
        r.title("Stage 06: inversion of control and dependency injection");

        r.heading("1. Dependency injection by hand: no framework needed");
        Candidate candidate = new Candidate(1);
        Composite byHand = new Composite(candidate, new DependencyB(), 10);
        byHand.init();
        r.kv("new Composite(new Candidate(1), new DependencyB(), 10); init()", byHand.state());
        r.kv("byHand.run()", byHand.run());
        r.note("Composite never creates its collaborators; it receives them. That alone is dependency injection, "
                + "and it is why Composite can be tested with fakes. The container that follows only automates the "
                + "'new' calls that Main writes here.");

        r.heading("2. The alternative: a service locator, and why it hides dependencies");
        try {
            new LocatorUser();
        } catch (IllegalStateException e) {
            r.kv("new LocatorUser() before anything is registered", "IllegalStateException: " + e.getMessage());
        }
        Locator.put(Dependency.class, new DependencyA());
        r.kv("Locator.put(Dependency.class, new DependencyA()); new LocatorUser().describe()", new LocatorUser().describe());
        r.note("LocatorUser's constructor takes nothing, yet it cannot be created without global setup. Its "
                + "dependencies are invisible in its signature. Constructor injection makes them explicit, which "
                + "is the whole argument for DI over locators.");

        r.heading("3. The container finds components by scanning the class path");
        Properties config = new Properties();
        try (InputStream in = Main.class.getResourceAsStream("/application.properties")) {
            config.load(in);
        }
        Container container = new Container(config);
        container.scan("sa4e.reflect");
        List<String[]> rows = new ArrayList<>();
        container.components().forEach((name, type) -> rows.add(new String[]{"`" + name + "`", type.getSimpleName(),
                type.isAnnotationPresent(Prototype.class) ? "prototype" : "singleton"}));
        r.table(new String[]{"Name", "Class", "Scope"}, rows);
        r.note("ClassScanner lists every class below the package, from directories and jars alike, and the container "
                + "keeps those annotated with @Component. Nothing is created yet: creation happens on the first request.");

        r.heading("4. Requesting a component: the container builds the whole graph");
        Composite composite = container.get(Composite.class);
        r.kv("container.get(Composite.class).state()", composite.state());
        r.kv("composite.run()", composite.run());
        r.code("", String.join("\n", container.trace()));
        r.note("Composite's @Inject constructor asks for a Capability named 'candidate', a Dependency named 'beta' and "
                + "the value composite.limit. Candidate in turn has an @Inject field, so DependencyA is created on the "
                + "way. @PostConstruct runs when the object is complete. Nobody wrote a single 'new'.");

        r.heading("5. Qualifiers: when several components implement the requested type");
        try {
            container.get(Capability.class);
        } catch (ContainerException e) {
            r.kv("container.get(Capability.class)", "ContainerException: " + e.getMessage());
        }
        r.kv("container.get(Capability.class, \"alternative\")", container.get(Capability.class, "alternative"));
        r.kv("container.get(Dependency.class, \"alpha\").name()", container.get(Dependency.class, "alpha").name());
        try {
            container.get(Runnable.class);
        } catch (ContainerException e) {
            r.kv("container.get(Runnable.class)", "ContainerException: " + e.getMessage());
        }
        r.note("Resolution is isAssignableFrom over the registered classes, plus the name from @Component or @Named. "
                + "Spring adds @Primary, profiles and conditions, but the core is this loop.");

        r.heading("6. Scopes: singletons are shared, prototypes are fresh");
        r.kv("container.get(Candidate.class) == container.get(Candidate.class)", container.get(Candidate.class) == container.get(Candidate.class));
        r.kv("the Candidate inside Composite is that same instance",
                composite.run().contains(container.get(Candidate.class).toString()));
        r.kv("container.get(Ephemeral.class)", container.get(Ephemeral.class));
        r.kv("container.get(Ephemeral.class) again", container.get(Ephemeral.class));
        r.kv("container.get(Ephemeral.class) == container.get(Ephemeral.class)", container.get(Ephemeral.class) == container.get(Ephemeral.class));
        r.note("Singleton is the default: one instance per container, created on first use. @Prototype means a new "
                + "instance per request. Web frameworks add request and session scopes on the same principle.");

        r.heading("7. Field injection reaches private fields, even in Candidate");
        r.kv("container.get(Candidate.class)", container.get(Candidate.class));
        r.kv("Candidate.class.getDeclaredField(\"dependency\").getModifiers()",
                java.lang.reflect.Modifier.toString(Candidate.class.getDeclaredField("dependency").getModifiers()));
        r.note("The field is private and has no setter; the container sets it with setAccessible(true) as in stage 02. "
                + "Convenient, but the dependency is invisible in the constructor and the object is incomplete until "
                + "the container is done. Prefer constructor injection; keep field injection for tests.");

        r.heading("8. Circular dependencies");
        try {
            container.get(Chicken.class);
        } catch (ContainerException e) {
            r.kv("container.get(Chicken.class)", "ContainerException: " + e.getMessage());
        }
        Ping ping = container.get(Ping.class);
        r.kv("container.get(Ping.class).pong.ping == ping", ping.pong.ping == ping);
        r.note("Chicken needs an Egg in its constructor and Egg a Chicken: neither can exist first. Ping and Pong use "
                + "field injection, so both objects exist before either field is set, and the container registers a "
                + "singleton before injecting its fields. Spring behaves the same way and still recommends breaking "
                + "the cycle instead.");

        r.heading("9. The other face of inversion of control: an event bus");
        EventBus bus = new EventBus();
        bus.register(composite);
        bus.register(container.get(Listener.class));
        r.kv("bus.subscriptions()", bus.subscriptions());
        r.kv("bus.post(new Event(\"started\"))", bus.post(new Event("started")) + " subscriber(s)");
        r.kv("bus.post(\"a plain string\")", bus.post("a plain string") + " subscriber(s)");
        r.kv("composite.received()", composite.received());
        r.kv("listener.seen()", container.get(Listener.class).seen());
        r.note("Subscribers are found by annotation and matched by the parameter type of the handler, with isInstance "
                + "from stage 01. The bus calls the handlers; the handlers never call the bus.");

        r.heading("10. Where control went");
        r.item("Stage 00: Main created every object and called every method.");
        r.item("Stage 03: the test runner called the test methods.");
        r.item("Stage 04: the proxy handlers decided what happens around each call.");
        r.item("Stage 06: the container creates the objects and wires them; the event bus decides who is called when.");
        r.item("Application code is reduced to declaring what it needs and what it offers. That is what makes Spring, "
                + "Jakarta EE and every other application framework feel like magic, and it is all reflection, "
                + "annotations, proxies and class loading.");
        r.flush();
    }
}
