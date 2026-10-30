# Stage 05: dynamic class loading

_Java 25+37-LTS-jvmci-b01, Java HotSpot(TM) 64-Bit Server VM (Oracle Corporation), /Users/sturm/.sdkman/candidates/java/25-graal_

## 1. Every class has a loader, and loaders form a hierarchy

| Expression                               | Result                                          |
|------------------------------------------|-------------------------------------------------|
| `String.class.getClassLoader()`          | null (null = bootstrap loader, part of the JVM) |
| `java.sql.Driver.class.getClassLoader()` | PlatformClassLoader "platform"                  |
| `Candidate.class.getClassLoader()`       | AppClassLoader "app"                            |
| `ClassLoader.getSystemClassLoader()`     | AppClassLoader "app"                            |
| `ClassLoader.getPlatformClassLoader()`   | PlatformClassLoader "platform"                  |
| `parent chain of the application loader` | app -> platform -> bootstrap                    |

> ℹ Parent-first delegation: a loader asks its parent before looking itself. This is why nobody can replace java.lang.String by putting a class of that name on the class path.

## 2. Loading is not initializing

| Expression                                                                | Result                            |
|---------------------------------------------------------------------------|-----------------------------------|
| `Class.forName("sa4e.reflect.Noisy", false, loader)`                      | class sa4e.reflect.Noisy          |
| `LoadEvents.EVENTS after loading`                                         | []                                |
| `noisy.getDeclaredFields().length (reflection on an uninitialized class)` | 2                                 |
| `LoadEvents.EVENTS after reflection`                                      | []                                |
| `Noisy.CONSTANT (a compile-time constant, inlined by javac)`              | 42                                |
| `LoadEvents.EVENTS after reading the constant`                            | []                                |
| `Noisy.counter (a real static field)`                                     | 1                                 |
| `LoadEvents.EVENTS after reading the field`                               | [static initializer of Noisy ran] |

> ℹ The JVM loads lazily and initializes even later: the static initializer runs at the first 'active use' (new, static method call, non-constant static field access). Class.forName(name) with one argument initializes immediately, which is how JDBC drivers used to register themselves.

## 3. The implementation is chosen by a configuration file

| Expression                                                | Result                                 |
|-----------------------------------------------------------|----------------------------------------|
| `application.properties`                                  | capability.impl=sa4e.reflect.Candidate |
| `effective name (overridable with -Dcapability.impl=...)` | sa4e.reflect.Candidate                 |
| `chosen.getClass()`                                       | Candidate                              |
| `chosen.f(3, 4.0); chosen`                                | Candidate{x=-3, label='candidate#0'}   |
| `the same with sa4e.reflect.Alternative`                  | Alternative{x=7}                       |

> ℹ asSubclass checks that the configured class really implements Capability and gives a typed Class<? extends Capability>. Main never mentions Candidate or Alternative; try ./run.sh 05 -Dcapability.impl=sa4e.reflect.Alternative

## 4. ServiceLoader: the JDK's own plugin registry

| Expression          | Result                                    |
|---------------------|-------------------------------------------|
| `registration file` | META-INF/services/sa4e.reflect.Capability |

```
# Implementations of sa4e.reflect.Capability, found by java.util.ServiceLoader.
sa4e.reflect.Candidate
sa4e.reflect.Alternative
```

| Expression                                                          | Result                                                   |
|---------------------------------------------------------------------|----------------------------------------------------------|
| `ServiceLoader.load(Capability.class).stream().map(Provider::type)` | [sa4e.reflect.Candidate, sa4e.reflect.Alternative]       |
| `instances after f(1, 1.0)`                                         | [Candidate{x=-1, label='candidate#0'}, Alternative{x=2}] |

> ℹ The file name is the interface, the lines are implementations with a public no-arg constructor. JDBC drivers, charset providers, logging back-ends and JAX-RS runtimes are found this way. With modules, 'provides ... with ...' in module-info.java replaces the file.

## 5. A plugin compiled from source while the program runs

| Expression    | Result                              |
|---------------|-------------------------------------|
| `source file` | stage05-loading/plugins/Plugin.java |

```java
// This file is NOT compiled by the build. Stage 05 compiles it while the program runs.
public class Plugin implements sa4e.reflect.Capability {

    private int x;

    @Override
    public int getX() {
        return x;
    }

    @Override
    public void f(int y, double d) {
        x = y * 2;
    }

    @Override
    public String toString() {
        return "Plugin version 1 {x=" + x + "}";
    }
}
```

| Expression                                           | Result                     |
|------------------------------------------------------|----------------------------|
| `compiled with javax.tools.JavaCompiler into`        | a temporary directory, v1  |
| `plugin.f(5, 0.0); plugin`                           | Plugin version 1 {x=10}    |
| `pluginClass.getClassLoader()`                       | URLClassLoader "plugin:v1" |
| `Capability.class.getClassLoader()`                  | AppClassLoader "app"       |
| `pluginClass.getInterfaces()[0] == Capability.class` | true                       |

> ℹ The plugin's own class comes from the new loader; Capability is resolved through the parent and is therefore the same Class object the application uses. That shared interface is the contract between host and plugin.

## 6. Two versions side by side: a class is identified by name and loader

| Expression                                                              | Result                                           |
|-------------------------------------------------------------------------|--------------------------------------------------|
| `second version compiled and loaded; plugin2`                           | Plugin version 2 {x=15}                          |
| `pluginClass.getName().equals(pluginClass2.getName())`                  | true                                             |
| `pluginClass == pluginClass2`                                           | false                                            |
| `pluginClass.isInstance(plugin2)`                                       | false                                            |
| `loading version 1 once more with a third loader: again == pluginClass` | false                                            |
| `pluginClass.cast(plugin2)`                                             | ClassCastException: Cannot cast Plugin to Plugin |

> ℹ 'Plugin cannot be cast to Plugin' is the famous symptom. Application servers redeploy a web application by throwing away its loader and creating a new one; the old classes are garbage collected once nothing references them, the loader or any of their instances.

## 7. Consequences

- Flexibility: implementations can be swapped by configuration, discovered by registration, or added after deployment.
- Security: loading a class executes its static initializer. Loading classes from untrusted locations is remote code execution; Log4Shell (2021) was JNDI fetching a class from an attacker's server.
- Isolation: separate loaders let two versions of the same library coexist (OSGi, application servers), at the price of ClassCastExceptions when objects cross the boundary.
- Closed-world compilers (GraalVM native image) cannot support this at all without a complete list of classes at build time.
