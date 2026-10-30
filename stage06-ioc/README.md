# Stage 06: inversion of control and dependency injection

## Pain in stage 05

Classes can now be chosen, discovered and loaded at run time, but somebody still has to create
the objects and connect them: `Main` is a long list of `new` and constructor arguments that
must be kept in the right order, and every object that creates its own collaborators is
welded to them.

## Mechanism

Inversion of control: the framework calls the application, not the other way round.
Dependency injection is its most important form: objects declare what they need, a container
creates them in dependency order and hands the collaborators in. The container is built from
everything the previous stages showed: classpath scanning (stage 05), `@Component`,
`@Inject`, `@Named`, `@Value` and `@PostConstruct` (stage 03), constructor and field access
through reflection (stage 02) and `isAssignableFrom` (stage 01).

`Main` walks through:

1. dependency injection by hand: constructor injection needs no framework
2. the service locator alternative and why hidden dependencies are a problem
3. the container scanning the class path and listing its components
4. one `get` request that builds the whole object graph, with a trace of every step
5. qualifiers and the ambiguity error
6. scopes: singletons and prototypes
7. field injection into a private field of `Candidate`
8. circular dependencies: constructor cycles fail, field cycles are resolvable
9. an event bus as the other face of inversion of control
10. a summary of where control went over the stages

## New files

| File | Purpose |
|---|---|
| `Component`, `Inject`, `Named`, `Prototype`, `PostConstruct`, `Value` | the container's annotations |
| `ClassScanner.java` | finds every class below a package in directories and jars |
| `Container.java`, `ContainerException.java` | the container: scan, resolve, construct, inject, post-construct, scopes, cycle detection |
| `Dependency`, `DependencyA`, `DependencyB` | an interface with two named implementations |
| `Composite.java` | constructor injection with qualifier and configuration value, `@PostConstruct`, `@Subscribe` |
| `Ephemeral.java` | a `@Prototype` component with a `@Value` field |
| `Chicken`, `Egg`, `Ping`, `Pong` | a constructor cycle and a field cycle |
| `Subscribe`, `EventBus`, `Event`, `Listener` | the event bus |
| `src/main/resources/application.properties` | values for `@Value` |

Changed: `Candidate` is a `@Component` with an `@Inject @Named("alpha") Dependency` field, and
`Alternative` is a `@Component` too. The loading helpers of stage 05 were dropped.

## In the real world

- Spring's `ApplicationContext`, Jakarta CDI, Guice and Dagger are this container with
  thousands of features on top: profiles, conditions, `@Primary`, lifecycle phases, proxies for
  scopes, AOP integration (stage 04), configuration binding, and eager validation at startup.
- JUnit (stage 03), servlet containers, message listeners and Spring's `@EventListener` are
  inversion of control without dependency injection: the framework decides when your code runs.
- Dagger shows the compile-time variant: the same annotations, but an annotation processor
  generates the wiring code, so no reflection is needed at run time.

## Cost

- Startup: scanning and reflection cost time; large Spring applications spend seconds here,
  which is why Spring AOT and GraalVM native image move this work to build time.
- Indirection: which implementation is injected is decided by annotations and configuration,
  not by code one can follow with "go to definition".
- Errors move from compile time to startup time (or, with lazy creation, to first use).
- Field injection and cycles are convenient and both hide design problems.

## Exercises

1. Add eager initialization: `container.start()` creates every singleton at once, so that a
   missing dependency fails at startup instead of on first use. What happens with `Chicken`?
2. Add `@Primary`, so that an ambiguous request picks the primary candidate instead of failing.
3. Let the container register every component with `@Subscribe` methods at the event bus
   automatically, so that section 9 needs no explicit `register` calls.
4. Combine stages: wrap every component that implements an interface in the logging proxy of
   stage 04 when it is created. Where in `Container` does that belong?

## Run

```
./run.sh 06
```

The output is Markdown; see [output.md](output.md) for the result of the last run.
