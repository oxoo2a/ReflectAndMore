# Stage 06: inversion of control and dependency injection

_Java 25+37-LTS-jvmci-b01, Java HotSpot(TM) 64-Bit Server VM (Oracle Corporation), /Users/sturm/.sdkman/candidates/java/25-graal_

## 1. Dependency injection by hand: no framework needed

| Expression                                                       | Result                                                  |
|------------------------------------------------------------------|---------------------------------------------------------|
| `new Composite(new Candidate(1), new DependencyB(), 10); init()` | initialized with Candidate, beta and limit 10           |
| `byHand.run()`                                                   | ran f(10, 1.0) on Candidate{x=-10, label='candidate#1'} |

> ℹ Composite never creates its collaborators; it receives them. That alone is dependency injection, and it is why Composite can be tested with fakes. The container that follows only automates the 'new' calls that Main writes here.

## 2. The alternative: a service locator, and why it hides dependencies

| Expression                                                                       | Result                                                   |
|----------------------------------------------------------------------------------|----------------------------------------------------------|
| `new LocatorUser() before anything is registered`                                | IllegalStateException: nothing registered for Dependency |
| `Locator.put(Dependency.class, new DependencyA()); new LocatorUser().describe()` | using alpha                                              |

> ℹ LocatorUser's constructor takes nothing, yet it cannot be created without global setup. Its dependencies are invisible in its signature. Constructor injection makes them explicit, which is the whole argument for DI over locators.

## 3. The container finds components by scanning the class path

| Name          | Class       | Scope     |
|---------------|-------------|-----------|
| `alternative` | Alternative | singleton |
| `candidate`   | Candidate   | singleton |
| `chicken`     | Chicken     | singleton |
| `composite`   | Composite   | singleton |
| `alpha`       | DependencyA | singleton |
| `beta`        | DependencyB | singleton |
| `egg`         | Egg         | singleton |
| `ephemeral`   | Ephemeral   | prototype |
| `listener`    | Listener    | singleton |
| `ping`        | Ping        | singleton |
| `pong`        | Pong        | singleton |

> ℹ ClassScanner lists every class below the package, from directories and jars alike, and the container keeps those annotated with @Component. Nothing is created yet: creation happens on the first request.

## 4. Requesting a component: the container builds the whole graph

| Expression                               | Result                                                                    |
|------------------------------------------|---------------------------------------------------------------------------|
| `container.get(Composite.class).state()` | initialized with Candidate, beta and limit 10                             |
| `composite.run()`                        | ran f(10, 1.0) on Candidate{x=-10, label='candidate#0', dependency=alpha} |

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

> ℹ Composite's @Inject constructor asks for a Capability named 'candidate', a Dependency named 'beta' and the value composite.limit. Candidate in turn has an @Inject field, so DependencyA is created on the way. @PostConstruct runs when the object is complete. Nobody wrote a single 'new'.

## 5. Qualifiers: when several components implement the requested type

| Expression                                        | Result                                                                                     |
|---------------------------------------------------|--------------------------------------------------------------------------------------------|
| `container.get(Capability.class)`                 | ContainerException: ambiguous request for Capability: [alternative, candidate]; use @Named |
| `container.get(Capability.class, "alternative")`  | Alternative{x=0}                                                                           |
| `container.get(Dependency.class, "alpha").name()` | alpha                                                                                      |
| `container.get(Runnable.class)`                   | ContainerException: no component for Runnable                                              |

> ℹ Resolution is isAssignableFrom over the registered classes, plus the name from @Component or @Named. Spring adds @Primary, profiles and conditions, but the core is this loop.

## 6. Scopes: singletons are shared, prototypes are fresh

| Expression                                                         | Result |
|--------------------------------------------------------------------|--------|
| `container.get(Candidate.class) == container.get(Candidate.class)` | true   |
| `the Candidate inside Composite is that same instance`             | true   |
| `container.get(Ephemeral.class)`                                   | tmp#1  |
| `container.get(Ephemeral.class) again`                             | tmp#2  |
| `container.get(Ephemeral.class) == container.get(Ephemeral.class)` | false  |

> ℹ Singleton is the default: one instance per container, created on first use. @Prototype means a new instance per request. Web frameworks add request and session scopes on the same principle.

## 7. Field injection reaches private fields, even in Candidate

| Expression                                                      | Result                                                  |
|-----------------------------------------------------------------|---------------------------------------------------------|
| `container.get(Candidate.class)`                                | Candidate{x=-10, label='candidate#0', dependency=alpha} |
| `Candidate.class.getDeclaredField("dependency").getModifiers()` | private                                                 |

> ℹ The field is private and has no setter; the container sets it with setAccessible(true) as in stage 02. Convenient, but the dependency is invisible in the constructor and the object is incomplete until the container is done. Prefer constructor injection; keep field injection for tests.

## 8. Circular dependencies

| Expression                                    | Result                                                             |
|-----------------------------------------------|--------------------------------------------------------------------|
| `container.get(Chicken.class)`                | ContainerException: circular dependency: Chicken -> Egg -> Chicken |
| `container.get(Ping.class).pong.ping == ping` | true                                                               |

> ℹ Chicken needs an Egg in its constructor and Egg a Chicken: neither can exist first. Ping and Pong use field injection, so both objects exist before either field is set, and the container registers a singleton before injecting its fields. Spring behaves the same way and still recommends breaking the cycle instead.

## 9. The other face of inversion of control: an event bus

| Expression                       | Result                                             |
|----------------------------------|----------------------------------------------------|
| `bus.subscriptions()`            | [Composite.on(Event), Listener.onAnything(Object)] |
| `bus.post(new Event("started"))` | 2 subscriber(s)                                    |
| `bus.post("a plain string")`     | 1 subscriber(s)                                    |
| `composite.received()`           | [started]                                          |
| `listener.seen()`                | [Event Event[name=started], String a plain string] |

> ℹ Subscribers are found by annotation and matched by the parameter type of the handler, with isInstance from stage 01. The bus calls the handlers; the handlers never call the bus.

## 10. Where control went

- Stage 00: Main created every object and called every method.
- Stage 03: the test runner called the test methods.
- Stage 04: the proxy handlers decided what happens around each call.
- Stage 06: the container creates the objects and wires them; the event bus decides who is called when.
- Application code is reduced to declaring what it needs and what it offers. That is what makes Spring, Jakarta EE and every other application framework feel like magic, and it is all reflection, annotations, proxies and class loading.
