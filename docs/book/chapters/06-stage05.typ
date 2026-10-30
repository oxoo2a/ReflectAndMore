#import "../template.typ": *

#chapter(num: "Stage 05", title: "Dynamic class loading", tagline: [In which classes arrive while the program is running, a class turns out to be not quite the same as itself, and we compile Java from inside Java.])

== Where we stand

Everything so far, proxies included, has worked on classes that existed when `javac` ran. Stage 01's `Class.forName` could turn a string into a class, but the class had to be on the class path from the start. A new implementation of `Capability` meant recompiling and redeploying the whole program.

Enterprise systems need the opposite. Choose an implementation by configuration. Discover implementations that were dropped into a directory. Add a plugin after deployment. Replace a component while the system runs. All of this rests on one piece of the JVM that most Java developers never touch directly: the class loader.

== Every class has a loader

A class is not loaded by "the JVM". It is loaded by a specific object, an instance of `java.lang.ClassLoader`, and the class remembers which one:

#results(
  ("String.class.getClassLoader()", "null (null = bootstrap loader, part of the JVM)"),
  ("java.sql.Driver.class.getClassLoader()", "PlatformClassLoader \"platform\""),
  ("Candidate.class.getClassLoader()", "AppClassLoader \"app\""),
  ("ClassLoader.getSystemClassLoader()", "AppClassLoader \"app\""),
  ("parent chain of the application loader", "app -> platform -> bootstrap"),
)

Three loaders exist before your program starts. The _bootstrap_ loader is part of the JVM itself, written in C++, and loads `java.base`: `String`, `Object`, `Class`. It has no Java object, which is why `String.class.getClassLoader()` is `null`. The _platform_ loader loads the rest of the JDK, `java.sql` for instance. The _application_ loader, also called the system loader, loads your class path: `Candidate`, `Main`, every jar you added.

They form a chain, and the chain has a rule: _parent first_. When the application loader is asked for a class, it asks the platform loader first, which asks the bootstrap loader first. Only if the parents do not have the class does a loader look in its own sources. This is why you cannot replace `java.lang.String` by putting a class of that name on your class path: the bootstrap loader answers first, every time.

== Loading is not initializing

Before adding loaders, a subtlety about the ones we have. A class goes through three phases: _loading_ (reading the bytes and creating the `Class` object), _linking_ (verification, preparation of static fields with default values), and _initialization_ (running the static initializers). They do not happen at the same time, and the gap is observable. Stage 05 adds a class that leaves a trace when it is initialized:

```java
public final class Noisy {
    static {
        LoadEvents.EVENTS.add("static initializer of Noisy ran");
    }
    public static final int CONSTANT = 42;   // compile-time constant: inlined by javac
    public static int counter = 1;           // a real static field
}
```

#results(
  ("Class.forName(\"sa4e.reflect.Noisy\", false, loader)", "class sa4e.reflect.Noisy"),
  ("LoadEvents.EVENTS after loading", "[]"),
  ("noisy.getDeclaredFields().length (reflection on an uninitialized class)", "2"),
  ("LoadEvents.EVENTS after reflection", "[]"),
  ("Noisy.CONSTANT (a compile-time constant, inlined by javac)", "42"),
  ("LoadEvents.EVENTS after reading the constant", "[]"),
  ("Noisy.counter (a real static field)", "1"),
  ("LoadEvents.EVENTS after reading the field", "[static initializer of Noisy ran]"),
)

The three-argument `Class.forName(name, false, loader)` loads without initializing. Reflection on the class works; `getDeclaredFields()` needs only the metadata. Reading `Noisy.CONSTANT` does not initialize either, for a reason that surprises people: `javac` saw a `static final int` with a constant value and inlined `42` into `Main`, so `Noisy` is not even consulted. Only `Noisy.counter`, a real static field, triggers initialization, and only then does the static block run.

The JVM initializes a class at its first _active use_: `new`, a static method call, a non-constant static field access. The one-argument `Class.forName(name)` counts as active use and initializes immediately, which brings us back to the JDBC idiom from stage 01: `Class.forName("org.postgresql.Driver")` was never about loading the driver, it was about running its static initializer, in which the driver registered itself with `DriverManager`. Stage 06's `ClassScanner` uses the three-argument form for the opposite reason: it looks at hundreds of classes and must not run any of their initializers.

== An implementation chosen by configuration

Now the first of three ways for code to arrive late. Stage 05 adds a second implementation of `Capability`, called `Alternative`, and a properties file:

```
capability.impl=sa4e.reflect.Candidate
```

```java
Properties config = new Properties();
config.load(Main.class.getResourceAsStream("/application.properties"));
String name = System.getProperty("capability.impl", config.getProperty("capability.impl"));

Capability chosen = Class.forName(name)
        .asSubclass(Capability.class)
        .getDeclaredConstructor()
        .newInstance();
```

#results(
  ("application.properties", "capability.impl=sa4e.reflect.Candidate"),
  ("effective name (overridable with -Dcapability.impl=...)", "sa4e.reflect.Candidate"),
  ("chosen.getClass()", "Candidate"),
  ("chosen.f(3, 4.0); chosen", "Candidate{x=-3, label='candidate#0'}"),
  ("the same with sa4e.reflect.Alternative", "Alternative{x=7}"),
)

`Main` mentions neither `Candidate` nor `Alternative`. The name comes from a file, or from the command line (`./run.sh 05 -Dcapability.impl=sa4e.reflect.Alternative` prints `Alternative{x=-3}` instead), and the only new call is `asSubclass`. It checks that the configured class really implements `Capability` and returns a `Class<? extends Capability>`, so that the result of `newInstance()` is typed without a cast. If the configuration names a class that does not implement the interface, `asSubclass` throws a `ClassCastException` at the point where the mistake can still be explained; without it, the cast would fail later and further away.

This is the oldest form of dependency injection, in use since before the term existed: JDBC drivers, JNDI providers, XML parser factories and logging back-ends were all selected by a class name in a system property.

== ServiceLoader: the JDK's own plugin registry

Configuration by class name requires somebody to write the name down. Often the better question is "which implementations are _available_?", and the JDK has had an answer since Java 6:

```
META-INF/services/sa4e.reflect.Capability
```
```
# Implementations of sa4e.reflect.Capability, found by java.util.ServiceLoader.
sa4e.reflect.Candidate
sa4e.reflect.Alternative
```

The file is named after the interface and lists implementations, one per line. Any jar on the class path can contribute such a file, and `ServiceLoader` collects them all:

```java
List<String> providers = ServiceLoader.load(Capability.class).stream()
        .map(p -> p.type().getName()).toList();       // type() does not instantiate

for (Capability c : ServiceLoader.load(Capability.class)) {   // iterating instantiates
    c.f(1, 1.0);
}
```

#results(
  ("ServiceLoader.load(Capability.class).stream().map(Provider::type)", "[sa4e.reflect.Candidate, sa4e.reflect.Alternative]"),
  ("instances after f(1, 1.0)", "[Candidate{x=-1, label='candidate#0'}, Alternative{x=2}]"),
)

Underneath, `ServiceLoader` does what stage 01 did: it finds the resource files with `getResources`, reads the names, and calls `Class.forName` and the public no-arg constructor. The value is in the convention. A JDBC driver jar contains `META-INF/services/java.sql.Driver`, and `DriverManager` finds it without anybody calling `Class.forName` any more. Charset providers, file system providers, JAX-RS runtimes, SLF4J back-ends and JUnit engines are all found this way, and with the module system the same thing is spelled `provides Capability with Candidate;` in `module-info.java`.

== A plugin compiled while the program runs

Both mechanisms so far still needed the class on the class path. The third does not. Stage 05 ships a source file that the build deliberately does not compile:

```java
// This file is NOT compiled by the build. Stage 05 compiles it while the program runs.
public class Plugin implements sa4e.reflect.Capability {
    private int x;
    public int getX() { return x; }
    public void f(int y, double d) { x = y * 2; }
    public String toString() { return "Plugin version 1 {x=" + x + "}"; }
}
```
#src[stage05-loading/plugins/Plugin.java]

Every JDK contains the compiler as a library, `javax.tools.JavaCompiler`, and calling it is a few lines:

```java
JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();   // null on a bare JRE
Files.writeString(outputDir.resolve("Plugin.java"), source);
int status = compiler.run(null, null, errors,
        "-classpath", System.getProperty("java.class.path"),   // Capability must resolve
        "-d", outputDir.toString(),
        outputDir.resolve("Plugin.java").toString());
```

Now the class file exists in a temporary directory that no loader knows about. So we make a loader that does:

```java
URL[] urls = {classesDir.toUri().toURL()};
URLClassLoader loader = new URLClassLoader("plugin:v1", urls,
        PluginLoader.class.getClassLoader());   // parent: the application loader
Class<?> pluginClass = loader.loadClass("Plugin");
Capability plugin = (Capability) pluginClass.getDeclaredConstructor().newInstance();
```

#results(
  ("plugin.f(5, 0.0); plugin", "Plugin version 1 {x=10}"),
  ("pluginClass.getClassLoader()", "URLClassLoader \"plugin:v1\""),
  ("Capability.class.getClassLoader()", "AppClassLoader \"app\""),
  ("pluginClass.getInterfaces()[0] == Capability.class", "true"),
)

Read the last three lines together; they are the whole theory of plugins. `Plugin` was loaded by the new `URLClassLoader`. Its interface `Capability` was not: the new loader asked its parent first, the parent is the application loader, and the application loader already had `Capability`. So the `Capability` the plugin implements is _the same `Class` object_ the host program uses, and the cast to `Capability` succeeds. The shared interface, loaded by a shared ancestor, is the contract between host and plugin. Everything the plugin defines itself lives in its own loader and could be thrown away with it.

== Two versions, side by side

Here is the experiment that explains a famous error message. Compile a second version of the same source, with two strings changed, into a second directory, and load it with a second loader:

#results(
  ("second version compiled and loaded; plugin2", "Plugin version 2 {x=15}"),
  ("pluginClass.getName().equals(pluginClass2.getName())", "true"),
  ("pluginClass == pluginClass2", "false"),
  ("pluginClass.isInstance(plugin2)", "false"),
  ("loading version 1 once more with a third loader: again == pluginClass", "false"),
  ("pluginClass.cast(plugin2)", "ClassCastException: Cannot cast Plugin to Plugin"),
)

Both classes are called `Plugin`. They are different classes. A class on the JVM is identified by its _name and its defining loader_, and two loaders that read the same bytes still produce two unrelated classes, as the fifth line shows. Stage 01 said there is exactly one `Class` object per loaded class; this is the fine print. "Cannot cast Plugin to Plugin" is the message you get when an object from one loader is handed to code that expects the same class from another loader, and once you have seen this experiment you will never be puzzled by it again.

The same fact is a feature. An application server can run two web applications that bundle different versions of the same library, because each application has its own loader and the two copies of `org.apache.commons.Whatever` never meet. And it can _redeploy_ an application by discarding its loader and creating a new one: the old classes become garbage as soon as nothing references them, the loader, or any of their instances. Version 2 of `Plugin` did not replace version 1 in the demo, it joined it; the host chooses which one to talk to.

== Consequences

#note[
  Loading a class runs its static initializer. That makes "load a class from an untrusted location" exactly equivalent to "run untrusted code". Log4Shell, the vulnerability of December 2021, was nothing more than Log4j letting a log message contain a JNDI lookup, and JNDI fetching a class from a server the attacker named. The whole mechanism of this chapter was in place; only the trust was missing.
]

- *Flexibility.* Implementations can be swapped by configuration, discovered by registration, or added after deployment, without touching the host.
- *Isolation.* Separate loaders let incompatible versions coexist and let components be unloaded, at the price of `ClassCastException` and `LinkageError` when objects cross a boundary they were not meant to cross.
- *Leaks.* A loader stays alive as long as anything references any of its classes. One lingering thread or one cached object keeps an entire redeployed application in memory; this was the classic application-server leak for a decade.
- *Closed worlds.* GraalVM native image decides at build time which classes exist. Nothing in this chapter is possible there unless the classes are known in advance.

#wild[
  - JDBC drivers, charset providers, `java.util.logging` and SLF4J back-ends, JAX-RS runtimes and JUnit engines are discovered with `ServiceLoader` or `Class.forName` from configuration.
  - Tomcat, Jetty, WildFly and every other application server give each deployed application its own loader, with parent-first delegation deliberately broken for the application's own libraries.
  - OSGi and the Java Platform Module System add versioning and visibility rules on top of loaders.
  - JSP engines, Groovy, the Java shell and IDE "evaluate expression" features compile source at run time like section five; hot swap in a debugger is the JVM-level cousin.
]

#bill[
  - Security: a loaded class is executed code. Never load from a location you do not trust.
  - `ClassCastException` across loaders, `LinkageError` when the same class is visible twice, memory leaks when an old loader is kept alive.
  - Everything that uses `Class.forName` is invisible to static analysis and to closed-world compilers.
  - Run-time compilation needs a JDK, not a JRE, and costs seconds.
]

#tryit[
  + Run `./run.sh 05 -Dcapability.impl=sa4e.reflect.Alternative`, then with a class that does not exist and with one that exists but does not implement `Capability`. Improve the error messages.
  + Package a third `Capability` as a jar in a `plugins/` directory and load it with `URLClassLoader` without compiling anything at run time.
  + Hold the version-1 loader only through a `WeakReference`, drop every other reference, call `System.gc()` and check whether it is collected. Then keep one plugin instance alive and repeat.
  + Replace `URLClassLoader` by your own `ClassLoader` subclass that reads class bytes from a `Map<String, byte[]>` and overrides `findClass`. (Stage 07 needs this.)
]

#takeaway[
  - Classes are loaded by loader objects in a parent-first chain: bootstrap, platform, application, and then whatever you create.
  - Loading, linking and initialization are separate; the static initializer runs at first active use, and `Class.forName(name)` forces it.
  - A class is identified by name _and_ loader. Same bytes, different loader: different class.
  - Configuration by name, `ServiceLoader` registration and custom loaders are the three ways code arrives late.
  - A loaded class is executed code; trust is the whole question.
]
