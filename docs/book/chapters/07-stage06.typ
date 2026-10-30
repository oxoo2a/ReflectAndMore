#import "../template.typ": *

#chapter(num: "Stage 06", title: "Inversion of control", tagline: [In which nobody writes `new` any more, a container builds the whole object graph from annotations, and we find out where control went.])

== Where we stand

By the end of stage 05 a class can be chosen by configuration, discovered by registration and loaded from anywhere. But somebody still has to _create the objects and connect them_. In every stage so far that somebody was `Main`, and in stage 06's own first section it still is:

```java
Candidate candidate = new Candidate(1);
Composite byHand = new Composite(candidate, new DependencyB(), 10);
byHand.init();
```

Three objects, three lines. A real application has three hundred objects, and the lines must be in dependency order, and every time a constructor gains a parameter every `new` must be revisited. Worse, the alternative to wiring in `Main` is that objects create their own collaborators, which welds them together and makes them untestable.

Stage 06 builds the thing that takes this job away from `Main`: a dependency-injection container. It is about 150 lines, and every one of them is something from an earlier chapter.

== Dependency injection by hand

Before the container, the principle, because the two are often confused. The component that needs collaborators looks like this:

```java
@Component
public final class Composite {
    private final Capability capability;
    private final Dependency dependency;
    private final int limit;
    private String state = "constructed, not yet initialized";

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
        state = "initialized with " + capability.getClass().getSimpleName()
                + ", " + dependency.name() + " and limit " + limit;
    }

    public String run() {
        capability.f(limit, 1.0);
        return "ran f(" + limit + ", 1.0) on " + capability;
    }
}
```
#src[stage06-ioc/src/main/java/sa4e/reflect/Composite.java (abridged)]

Ignore the annotations for a moment and look at the constructor. `Composite` does not create a `Capability` or a `Dependency`; it _receives_ them. That alone is dependency injection. It is a design principle, not a framework feature, and it has an immediate benefit: `Composite` can be constructed in a test with a fake `Dependency` and no container anywhere in sight:

#results(
  ("new Composite(new Candidate(1), new DependencyB(), 10); init()", "initialized with Candidate, beta and limit 10"),
  ("byHand.run()", "ran f(10, 1.0) on Candidate{x=-10, label='candidate#1'}"),
)

The container that follows automates the `new` calls. It does not change the principle.

== The alternative, and why it hides things

There is an older pattern that solves the same problem differently, and it is worth seeing once so that you recognise it in legacy code:

```java
static final class Locator {
    private static final Map<Class<?>, Object> REGISTRY = new HashMap<>();
    static <T> void put(Class<T> type, T instance) { REGISTRY.put(type, instance); }
    static <T> T get(Class<T> type) { /* look up or throw */ }
}

static final class LocatorUser {
    private final Dependency dependency = Locator.get(Dependency.class);   // pulled
    String describe() { return "using " + dependency.name(); }
}
```

#results(
  ("new LocatorUser() before anything is registered", "IllegalStateException: nothing registered for Dependency"),
  ("Locator.put(Dependency.class, new DependencyA()); new LocatorUser().describe()", "using alpha"),
)

The _service locator_ is a global registry that components pull from. It works, and it is why it is called an anti-pattern rather than a mistake: `LocatorUser`'s constructor takes nothing, yet `new LocatorUser()` fails unless some global setup ran first. Its dependency is invisible in its signature, invisible to the compiler, invisible to the person writing a test. Constructor injection makes the dependency explicit, which is the whole argument for injection over location.

== The container finds its components

Now the framework. Step one is knowing what exists:

```java
Container container = new Container(config);
container.scan("sa4e.reflect");
```

`scan` uses a `ClassScanner` that does what stage 05's `ServiceLoader` does for one interface, for every class: it asks the loader for every location of the package (`getResources`), walks directories and jar entries, and calls the three-argument `Class.forName(name, false, loader)` on each name so that no static initializer runs. Of the result, the container keeps what carries `@Component`:

#table(
  columns: (auto, auto, auto),
  [Name], [Class], [Scope],
  [#m("alternative")], [Alternative], [singleton],
  [#m("candidate")], [Candidate], [singleton],
  [#m("chicken")], [Chicken], [singleton],
  [#m("composite")], [Composite], [singleton],
  [#m("alpha")], [DependencyA], [singleton],
  [#m("beta")], [DependencyB], [singleton],
  [#m("egg")], [Egg], [singleton],
  [#m("ephemeral")], [Ephemeral], [prototype],
  [#m("listener")], [Listener], [singleton],
  [#m("ping")], [Ping], [singleton],
  [#m("pong")], [Pong], [singleton],
)

A component's name is the value of `@Component("alpha")` or, by default, the decapitalised simple class name. Nothing has been created yet. The JDK has no API for "list all classes in a package", so every container writes this scanner, and it is the reason a large Spring application spends its first seconds reading class files.

== One request builds the graph

```java
Composite composite = container.get(Composite.class);
```

#results(
  ("container.get(Composite.class).state()", "initialized with Candidate, beta and limit 10"),
  ("composite.run()", "ran f(10, 1.0) on Candidate{x=-10, label='candidate#0', dependency=alpha}"),
)

One call, and `Composite` exists, fully wired. The container keeps a trace of what it did, and the trace is the best explanation of how a container works:

```
scanned sa4e.reflect: 11 components
construct Candidate with 0 argument(s)
construct DependencyA with 0 argument(s)
ready: DependencyA (singleton)
inject Candidate.dependency = the DependencyA instance
ready: Candidate (singleton)
construct DependencyB with 0 argument(s)
ready: DependencyB (singleton)
config Composite parameter limit = 10
construct Composite with 3 argument(s)
post-construct Composite.init()
ready: Composite (singleton)
```

Read it top to bottom. To build `Composite` the container looked at its `@Inject` constructor and found three parameters. The first, `@Named("candidate") Capability`, resolves to `Candidate`; building `Candidate` revealed an `@Inject` field of type `Dependency` named `alpha`, so `DependencyA` was built first and injected. The second parameter resolves to `DependencyB`. The third is a `@Value`, read from `application.properties` and converted to `int`. With all three in hand, `Composite` was constructed, its `@PostConstruct` method was called, and it was stored as a singleton. Depth-first, dependencies before dependents, and nobody wrote a single `new`.

The code behind the trace is short enough to read in full. Resolution is stage 01:

```java
private Class<?> resolve(Class<?> type, String name) {
    List<String> matches = new ArrayList<>();
    for (Map.Entry<String, Class<?>> e : components.entrySet()) {
        boolean nameFits = name == null || name.equals(e.getKey());
        if (type.isAssignableFrom(e.getValue()) && nameFits) {
            matches.add(e.getKey());
        }
    }
    if (matches.isEmpty()) throw new ContainerException("no component for " + request);
    if (matches.size() > 1) throw new ContainerException("ambiguous request for " + request
            + ": " + matches + "; use @Named");
    return components.get(matches.getFirst());
}
```

Construction is stage 02 with annotations from stage 03:

```java
private Object construct(Class<?> implementation) {
    Constructor<?> constructor = chooseConstructor(implementation); // @Inject or no-arg
    Parameter[] parameters = constructor.getParameters();
    Object[] arguments = new Object[parameters.length];
    for (int i = 0; i < parameters.length; i++) {
        arguments[i] = valueFor(parameters[i].getType(), parameters[i], /* where */);
    }
    constructor.setAccessible(true);
    return constructor.newInstance(arguments);
}

/** What goes into a parameter or field: a configuration value, or another component. */
private Object valueFor(Class<?> type, AnnotatedElement element, String where) {
    Value value = element.getAnnotation(Value.class);
    if (value != null) {
        String key = value.value().replaceAll("^\\$\\{|}$", "");
        return convert(config.getProperty(key), type);
    }
    Named named = element.getAnnotation(Named.class);
    return instance(resolve(type, named == null ? null : named.value()));   // recursion
}
```
#src[stage06-ioc/src/main/java/sa4e/reflect/Container.java (abridged)]

`valueFor` is where the recursion lives: a parameter that is not a configuration value is another component, so `instance` is called for it, which calls `construct`, which calls `valueFor` for _its_ parameters. The whole object graph is built by this recursion. Field injection and `@PostConstruct` are two more loops over `getDeclaredFields()` and `getDeclaredMethods()`, with `setAccessible(true)` and `invoke`.

== Qualifiers

Two components implement `Capability`. Ask for it without saying which:

#results(
  ("container.get(Capability.class)", "ContainerException: ambiguous request for Capability: [alternative, candidate]; use @Named"),
  ("container.get(Capability.class, \"alternative\")", "Alternative{x=0}"),
  ("container.get(Dependency.class, \"alpha\").name()", "alpha"),
  ("container.get(Runnable.class)", "ContainerException: no component for Runnable"),
)

The container refuses to guess, and says what it found. That is a deliberate choice and the right one: a container that silently picks the first match produces bugs that appear when a second implementation is added months later. `@Named` on the parameter or field settles it, and real containers add `@Primary`, profiles and conditions on top of the same loop.

== Scopes

#results(
  ("container.get(Candidate.class) == container.get(Candidate.class)", "true"),
  ("the Candidate inside Composite is that same instance", "true"),
  ("container.get(Ephemeral.class)", "tmp#1"),
  ("container.get(Ephemeral.class) again", "tmp#2"),
  ("container.get(Ephemeral.class) == container.get(Ephemeral.class)", "false"),
)

By default a component is a _singleton_: one instance per container, created on first request and shared by everyone who asks. `Composite` and `Main` got the same `Candidate`. A class marked `@Prototype` yields a new instance per request. The implementation is one `if` and one map; web frameworks add request and session scopes with the same shape and a proxy from stage 04 in front, so that a singleton can hold a reference to "the current request's" object.

== Field injection reaches into Candidate

`Candidate` changed for this stage, for the first time since stage 04:

```java
@Component
public class Candidate implements Capability {
    @Inject
    @Named("alpha")
    private Dependency dependency;     // filled by the container after construction
    // ...
}
```

#results(
  ("container.get(Candidate.class)", "Candidate{x=-10, label='candidate#0', dependency=alpha}"),
  ("Candidate.class.getDeclaredField(\"dependency\").getModifiers()", "private"),
)

The field is private and there is no setter; the container writes it with `setAccessible(true)` exactly as in stage 02. This is _field injection_, and it is convenient: no constructor to maintain. It is also the style most experienced people advise against, because the dependency is invisible in the constructor, the object is incomplete between construction and injection, and a test must either use the container or use reflection itself. Prefer constructor injection; keep field injection for tests and for the chapter that needs to show it.

== Cycles

What if `Chicken` needs an `Egg` in its constructor and `Egg` needs a `Chicken`?

#results(
  ("container.get(Chicken.class)", "ContainerException: circular dependency: Chicken -> Egg -> Chicken"),
  ("container.get(Ping.class).pong.ping == ping", "true"),
)

Neither can exist first, and the container says so, with the path. The detection is a stack of "classes under construction": if a class is requested while it is already on the stack, the request is circular. `Ping` and `Pong` have the same cycle through `@Inject` _fields_, and that works, because an object can be constructed, registered as a singleton, and only then have its fields filled; by the time `Pong` asks for `Ping`, `Ping` already exists. Spring behaves the same way, and its documentation still recommends breaking the cycle instead of relying on this.

== The other face of inversion of control

Dependency injection is the most important form of inversion of control, but not the only one. Stage 06 ends with a second one, built from the same parts:

```java
public final class EventBus {
    private record Subscription(Object target, Method method, Class<?> eventType) {}
    private final List<Subscription> subscriptions = new ArrayList<>();

    public void register(Object subscriber) {
        for (Method m : subscriber.getClass().getDeclaredMethods()) {
            if (!m.isAnnotationPresent(Subscribe.class)) continue;
            m.setAccessible(true);
            subscriptions.add(new Subscription(subscriber, m, m.getParameterTypes()[0]));
        }
    }

    public int post(Object event) {
        int delivered = 0;
        for (Subscription s : subscriptions) {
            if (!s.eventType().isInstance(event)) continue;   // stage 01
            s.method().invoke(s.target(), event);              // stage 02
            delivered++;
        }
        return delivered;
    }
}
```
#src[stage06-ioc/src/main/java/sa4e/reflect/EventBus.java (abridged)]

#results(
  ("bus.subscriptions()", "[Composite.on(Event), Listener.onAnything(Object)]"),
  ("bus.post(new Event(\"started\"))", "2 subscriber(s)"),
  ("bus.post(\"a plain string\")", "1 subscriber(s)"),
  ("composite.received()", "[started]"),
  ("listener.seen()", "[Event Event[name=started], String a plain string]"),
)

A handler is found by annotation and matched by the type of its single parameter; `Listener.onAnything(Object)` therefore receives everything. The bus calls the handlers; the handlers never call the bus. Guava's `EventBus` and Spring's `@EventListener` are this with threading and error handling.

== Where control went

Look back at the stages and ask, for each, who calls whom:

- *Stage 00.* `Main` created every object and called every method. Control was entirely in application code.
- *Stage 03.* The test runner called the test methods. The test class only declared.
- *Stage 04.* The proxy handlers decided what happens around every call. The real object did not know.
- *Stage 06.* The container creates the objects and wires them. The event bus decides who is called when. `Main` has become `container.get(Composite.class)`.

Application code has been reduced to _declaring what it needs and what it offers_. That is what makes Spring, Jakarta EE and every other application framework feel like magic, and it is reflection (stage 02), annotations (stage 03), proxies (stage 04) and class loading (stage 05), arranged. The stage 06 container does not use proxies, but the exercises ask you to combine them, and the moment you wrap every component in a `LoggingHandler` on creation you have Spring AOP.

#wild[
  - Spring's `ApplicationContext`, Jakarta CDI, Guice and Dagger are this container with thousands of features: profiles, conditions, `@Primary`, lifecycle phases, scoped proxies, AOP integration, configuration binding, and eager validation at startup.
  - JUnit (stage 03), servlet containers, message listeners, GUI event loops and Spring's `@EventListener` are inversion of control without dependency injection: the framework decides when your code runs.
  - Dagger is the compile-time variant: the same annotations, but an annotation processor generates the wiring code, and no reflection happens at run time.
  - `jakarta.inject` standardises exactly our vocabulary: `@Inject`, `@Named`, `@Singleton`, `Provider`.
]

#bill[
  - Startup: scanning and reflection take time. Large Spring applications spend seconds here, which is why Spring AOT and GraalVM native image move the work to build time.
  - Indirection: which implementation is injected is decided by annotations and configuration, not by code one can follow with "go to definition".
  - Errors move from compile time to startup time, or, with lazy creation as here, to the first request. Real containers create all singletons eagerly for exactly this reason.
  - Field injection and field-injection cycles are convenient and both hide design problems.
]

#tryit[
  + Add eager initialization: `container.start()` creates every singleton at once, so that a missing dependency fails at startup. What happens with `Chicken`?
  + Add `@Primary`, so that an ambiguous request picks the primary candidate instead of failing.
  + Let the container register every component that has `@Subscribe` methods with the event bus automatically, so that the last section needs no explicit `register` calls.
  + Combine stages: wrap every component that implements an interface in stage 04's `LoggingHandler` when it is created. Where in `Container` does that belong, and what breaks when a component is requested by its concrete class?
]

#takeaway[
  - Dependency injection is a principle: objects receive collaborators instead of creating them. The container only automates the `new` calls.
  - A container is classpath scanning plus a recursive `resolve`, `construct`, `inject`, `post-construct` loop, built entirely from stages 01 to 03.
  - Ambiguity is an error, not a guess. Singletons are shared, prototypes are fresh. Constructor cycles fail; field cycles resolve.
  - Inversion of control means the framework calls you. Injection and event buses are two faces of the same idea.
]
