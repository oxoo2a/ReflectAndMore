# ReflectAndMore

Lecture material for *Software Architectures for Enterprises* (SA4E, Universität Trier, winter 2026/27).

One small Java program grows stage by stage from plain Java to the meta-programming mechanisms
that enterprise frameworks are built on: run-time type information, reflection, annotations,
dynamic proxies, dynamic class loading, inversion of control and run-time code generation.
At the end the application code looks like a Spring or Jakarta EE application, and every
mechanism underneath has been written by hand. Frameworks are not magic.

The program has no business meaning on purpose. The class under investigation is simply
called `Candidate`; everything else is named after its role in the mechanism (`Inspector`,
`Interceptor`, `Container`, `Plugin`, `Dependency`), so that the pattern itself stays visible.

Pure JDK 25, no third-party dependencies.

## Stages

Each stage is a complete, runnable copy of the program in its own folder. The difference between
two neighbouring folders is exactly one lecture step.

| Stage | Question it answers | Mechanism |
|---|---|---|
| [stage00-plain](stage00-plain/) | What does the program look like without any meta-programming? | nothing yet |
| [stage01-rtti](stage01-rtti/) | What does the JVM know about `Candidate` at run time? | `Class` objects, hierarchy, `Class.forName`, sealed/record/enum introspection, erasure |
| [stage02-reflection](stage02-reflection/) | Can a program read and operate `Candidate` without knowing it at compile time? | `Inspector` (XML description), `Invoker`, private access, encapsulation, `MethodHandle` |
| stage03-annotations | How does `Candidate` tell a framework something extra? | `@Comment`, target and retention, repeatable and inherited, a generic validator |
| stage04-proxies | How do we add behaviour around `Candidate` without touching it? | `java.lang.reflect.Proxy`, interceptor chains, remote stub and skeleton |
| stage05-loading | How does code arrive that did not exist at compile time? | configuration, `ServiceLoader`, run-time compiled plugin, class loaders and identity |
| stage06-ioc | Who creates `Candidate` and fills its dependencies? | `@Inject`, `@Named`, `@Value`, `@PostConstruct`, container with classpath scanning, event bus |
| stage07-codegen | What if the class itself is written at run time? | ClassFile API, generated subclass proxy, hidden classes |

Stages that are not linked yet do not exist yet.

## Running a stage

With nothing but a JDK 25:

```
./run.sh 01
```

With Maven:

```
mvn -q package
java -jar stage01-rtti/target/stage01-rtti-2026W.jar
```

## Seeing what a stage adds

```
tools/diff-stages.sh 01        # stage00 -> stage01
tools/diff-stages.sh 03 05     # stage03 -> stage05
```

## Conventions

- All stages use the same package `sa4e.reflect` and the same entry point `sa4e.reflect.Main`,
  so that diffs between stages show only the real change.
- Every stage README follows the same rhythm: pain in the previous stage, mechanism, what real
  frameworks do with it, what it costs, exercises.
- Each stage's `Main` demonstrates only the new mechanism; earlier material stays in the earlier
  folder. Helper classes are carried forward only while a later stage still uses them.
- `Candidate` changes only when the next mechanism needs it (an interface, an annotation, an
  injected field). Everything that grows is the framework around it.
