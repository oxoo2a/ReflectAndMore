# Stage 05: dynamic class loading

## Pain in stage 04

Everything so far, proxies included, works on classes that existed when `javac` ran. A new
implementation of `Capability` means recompiling and redeploying the whole program. Enterprise
systems need the opposite: choose implementations by configuration, discover them by
registration, add them after deployment, replace them while running.

## Mechanism

Class loaders. A class is not loaded by "the JVM" but by a specific loader object, and loaders
form a parent-first hierarchy. A class is identified by its name *and* its loader. New loaders
can be created at any time and can fetch bytes from anywhere: a directory, a jar, a network
connection, or a compiler that just ran.

`Main` walks through:

1. the loader hierarchy: bootstrap, platform, application, and parent-first delegation
2. loading versus initialization, shown with a static initializer that leaves a trace
3. the implementation chosen by `application.properties`, overridable with `-D`
4. `ServiceLoader` and the `META-INF/services` registration file
5. a plugin compiled from source with `javax.tools.JavaCompiler` and loaded with a `URLClassLoader`
6. two versions of the same class side by side, and "Plugin cannot be cast to Plugin"
7. consequences: flexibility, security, isolation, closed-world compilers

## New files

| File | Purpose |
|---|---|
| `Alternative.java` | a second `Capability`, so that there is something to choose |
| `Noisy.java`, `LoadEvents.java` | a class whose static initializer leaves a trace |
| `RuntimeCompiler.java` | compiles a class at run time with the JDK's own compiler |
| `PluginLoader.java` | loads a class from a directory with a fresh `URLClassLoader` |
| `plugins/Plugin.java` | plugin source, deliberately outside `src/`, compiled only at run time |
| `src/main/resources/application.properties` | names the implementation to use |
| `src/main/resources/META-INF/services/sa4e.reflect.Capability` | `ServiceLoader` registration |

`Candidate` is unchanged. The proxy classes of stage 04 were dropped.

## In the real world

- JDBC drivers, `java.util.logging` and SLF4J back-ends, charset providers and the JAX-RS
  runtime are discovered with `ServiceLoader` or `Class.forName` from configuration.
- Tomcat, Jetty, WildFly and every other application server give each deployed application its
  own loader, so applications are isolated and can be redeployed without a restart.
- OSGi and the Java Platform Module System add versioning and visibility rules on top.
- JSP engines, Groovy and the Java shell compile source at run time exactly like section 5.
- IDEs, build tools and test runners reload classes with fresh loaders; "hot swap" in a
  debugger is the JVM-level variant.

## Cost

- Security: loading a class runs its static initializer. Loading from untrusted sources is
  remote code execution (Log4Shell).
- `ClassCastException` and `LinkageError` when objects cross loader boundaries, and memory
  leaks when an old loader is kept alive by a single lingering reference (the classic
  application-server leak).
- Everything that uses `Class.forName` is invisible to closed-world tools such as GraalVM
  native image unless declared in advance.

## Exercises

1. Run `./run.sh 05 -Dcapability.impl=sa4e.reflect.Alternative` and then with a class name
   that does not exist. Improve the error message `Main` prints.
2. Write a third `Capability` as a jar in a `plugins/` directory and load it with
   `URLClassLoader` without compiling anything at run time.
3. Hold the version-1 loader only through a `WeakReference`, drop all other references, call
   `System.gc()` and check whether the loader is collected. Then keep one plugin instance alive
   and repeat.
4. Replace `URLClassLoader` by your own `ClassLoader` subclass that reads class bytes from a
   `Map<String, byte[]>` and overrides `findClass`.

## Run

```
./run.sh 05
./run.sh 05 -Dcapability.impl=sa4e.reflect.Alternative
```

The output is Markdown; see [output.md](output.md) for the result of the last run.
