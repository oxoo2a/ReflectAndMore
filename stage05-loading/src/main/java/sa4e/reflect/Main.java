package sa4e.reflect;

import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.ServiceLoader;

/**
 * Stage 05: dynamic class loading.
 * <p>
 * So far every class existed when the program was compiled. Now classes arrive at run time:
 * chosen by a configuration file, registered as a service, or compiled from source while the
 * program runs. The key is the class loader: who loads a class decides where the bytes come
 * from, and a class is identified by its name <em>and</em> its loader.
 */
public final class Main {

    private static final String PLUGIN_NAME = "Plugin";

    public static void main(String[] args) throws Exception {
        Report r = Report.stdout();
        r.title("Stage 05: dynamic class loading");

        r.heading("1. Every class has a loader, and loaders form a hierarchy");
        r.kv("String.class.getClassLoader()", loader(String.class.getClassLoader()) + " (null = bootstrap loader, part of the JVM)");
        r.kv("java.sql.Driver.class.getClassLoader()", loader(java.sql.Driver.class.getClassLoader()));
        r.kv("Candidate.class.getClassLoader()", loader(Candidate.class.getClassLoader()));
        r.kv("ClassLoader.getSystemClassLoader()", loader(ClassLoader.getSystemClassLoader()));
        r.kv("ClassLoader.getPlatformClassLoader()", loader(ClassLoader.getPlatformClassLoader()));
        List<String> chain = new ArrayList<>();
        for (ClassLoader l = Candidate.class.getClassLoader(); l != null; l = l.getParent()) chain.add(l.getName());
        chain.add("bootstrap");
        r.kv("parent chain of the application loader", String.join(" -> ", chain));
        r.note("Parent-first delegation: a loader asks its parent before looking itself. This is why nobody can "
                + "replace java.lang.String by putting a class of that name on the class path.");

        r.heading("2. Loading is not initializing");
        ClassLoader app = Main.class.getClassLoader();
        Class<?> noisy = Class.forName("sa4e.reflect.Noisy", false, app);     // load and link, do not initialize
        r.kv("Class.forName(\"sa4e.reflect.Noisy\", false, loader)", noisy);
        r.kv("LoadEvents.EVENTS after loading", LoadEvents.EVENTS);
        r.kv("noisy.getDeclaredFields().length (reflection on an uninitialized class)", noisy.getDeclaredFields().length);
        r.kv("LoadEvents.EVENTS after reflection", LoadEvents.EVENTS);
        r.kv("Noisy.CONSTANT (a compile-time constant, inlined by javac)", Noisy.CONSTANT);
        r.kv("LoadEvents.EVENTS after reading the constant", LoadEvents.EVENTS);
        r.kv("Noisy.counter (a real static field)", Noisy.counter);
        r.kv("LoadEvents.EVENTS after reading the field", LoadEvents.EVENTS);
        r.note("The JVM loads lazily and initializes even later: the static initializer runs at the first 'active use' "
                + "(new, static method call, non-constant static field access). Class.forName(name) with one argument "
                + "initializes immediately, which is how JDBC drivers used to register themselves.");

        r.heading("3. The implementation is chosen by a configuration file");
        Properties config = new Properties();
        try (InputStream in = Main.class.getResourceAsStream("/application.properties")) {
            config.load(in);
        }
        String configured = System.getProperty("capability.impl", config.getProperty("capability.impl"));
        r.kv("application.properties", "capability.impl=" + config.getProperty("capability.impl"));
        r.kv("effective name (overridable with -Dcapability.impl=...)", configured);
        Capability chosen = Class.forName(configured).asSubclass(Capability.class).getDeclaredConstructor().newInstance();
        chosen.f(3, 4.0);
        r.kv("chosen.getClass()", chosen.getClass().getSimpleName());
        r.kv("chosen.f(3, 4.0); chosen", chosen);
        Capability other = Class.forName("sa4e.reflect.Alternative").asSubclass(Capability.class).getDeclaredConstructor().newInstance();
        other.f(3, 4.0);
        r.kv("the same with sa4e.reflect.Alternative", other);
        r.note("asSubclass checks that the configured class really implements Capability and gives a typed Class<? extends Capability>. "
                + "Main never mentions Candidate or Alternative; try ./run.sh 05 -Dcapability.impl=sa4e.reflect.Alternative");

        r.heading("4. ServiceLoader: the JDK's own plugin registry");
        URL registration = Main.class.getResource("/META-INF/services/sa4e.reflect.Capability");
        r.kv("registration file", "META-INF/services/sa4e.reflect.Capability");
        r.code("", new String(registration.openStream().readAllBytes()));
        List<String> providers = ServiceLoader.load(Capability.class).stream()
                .map(p -> p.type().getName()).toList();                  // type() does not instantiate
        r.kv("ServiceLoader.load(Capability.class).stream().map(Provider::type)", providers);
        List<String> instances = new ArrayList<>();
        for (Capability c : ServiceLoader.load(Capability.class)) {      // iterating instantiates lazily
            c.f(1, 1.0);
            instances.add(c.toString());
        }
        r.kv("instances after f(1, 1.0)", instances);
        r.note("The file name is the interface, the lines are implementations with a public no-arg constructor. "
                + "JDBC drivers, charset providers, logging back-ends and JAX-RS runtimes are found this way. "
                + "With modules, 'provides ... with ...' in module-info.java replaces the file.");

        r.heading("5. A plugin compiled from source while the program runs");
        Path source = findPluginSource();
        if (source == null) {
            r.note("plugins/Plugin.java not found next to this stage; skipping sections 5 and 6. "
                    + "Run from the repository root or the stage directory.");
            r.flush();
            return;
        }
        String version1 = Files.readString(source);
        r.kv("source file", source.normalize());
        r.code("java", version1);
        Path work = Files.createTempDirectory("reflect-plugins");
        Path dir1 = RuntimeCompiler.compile(PLUGIN_NAME, version1, work.resolve("v1"));
        r.kv("compiled with javax.tools.JavaCompiler into", "a temporary directory, " + dir1.getFileName());
        Class<?> pluginClass = PluginLoader.load(dir1, PLUGIN_NAME);
        Capability plugin = (Capability) pluginClass.getDeclaredConstructor().newInstance();
        plugin.f(5, 0.0);
        r.kv("plugin.f(5, 0.0); plugin", plugin);
        r.kv("pluginClass.getClassLoader()", loader(pluginClass.getClassLoader()));
        r.kv("Capability.class.getClassLoader()", loader(Capability.class.getClassLoader()));
        r.kv("pluginClass.getInterfaces()[0] == Capability.class", pluginClass.getInterfaces()[0] == Capability.class);
        r.note("The plugin's own class comes from the new loader; Capability is resolved through the parent and is "
                + "therefore the same Class object the application uses. That shared interface is the contract "
                + "between host and plugin.");

        r.heading("6. Two versions side by side: a class is identified by name and loader");
        String version2 = version1.replace("version 1", "version 2").replace("y * 2", "y * 3");
        Path dir2 = RuntimeCompiler.compile(PLUGIN_NAME, version2, work.resolve("v2"));
        Class<?> pluginClass2 = PluginLoader.load(dir2, PLUGIN_NAME);
        Capability plugin2 = (Capability) pluginClass2.getDeclaredConstructor().newInstance();
        plugin2.f(5, 0.0);
        r.kv("second version compiled and loaded; plugin2", plugin2);
        r.kv("pluginClass.getName().equals(pluginClass2.getName())", pluginClass.getName().equals(pluginClass2.getName()));
        r.kv("pluginClass == pluginClass2", pluginClass == pluginClass2);
        r.kv("pluginClass.isInstance(plugin2)", pluginClass.isInstance(plugin2));
        Class<?> again = PluginLoader.load(dir1, PLUGIN_NAME);
        r.kv("loading version 1 once more with a third loader: again == pluginClass", again == pluginClass);
        try {
            pluginClass.cast(plugin2);
        } catch (ClassCastException e) {
            r.kv("pluginClass.cast(plugin2)", "ClassCastException: " + e.getMessage());
        }
        r.note("'Plugin cannot be cast to Plugin' is the famous symptom. Application servers redeploy a web application "
                + "by throwing away its loader and creating a new one; the old classes are garbage collected once "
                + "nothing references them, the loader or any of their instances.");

        r.heading("7. Consequences");
        r.item("Flexibility: implementations can be swapped by configuration, discovered by registration, or added after deployment.");
        r.item("Security: loading a class executes its static initializer. Loading classes from untrusted "
                + "locations is remote code execution; Log4Shell (2021) was JNDI fetching a class from an attacker's server.");
        r.item("Isolation: separate loaders let two versions of the same library coexist (OSGi, application servers), "
                + "at the price of ClassCastExceptions when objects cross the boundary.");
        r.item("Closed-world compilers (GraalVM native image) cannot support this at all without a complete list of classes at build time.");
        r.flush();
    }

    /** Class name and name of a loader; the default toString would contain a changing hash. */
    private static String loader(ClassLoader l) {
        return l == null ? "null" : l.getClass().getSimpleName() + " \"" + l.getName() + "\"";
    }

    /** Looks for plugins/Plugin.java relative to the working directory or the location of this class. */
    private static Path findPluginSource() {
        List<Path> candidates = new ArrayList<>();
        candidates.add(Paths.get("plugins", PLUGIN_NAME + ".java"));
        candidates.add(Paths.get("stage05-loading", "plugins", PLUGIN_NAME + ".java"));
        try {
            Path code = Paths.get(Main.class.getProtectionDomain().getCodeSource().getLocation().toURI());
            for (Path p = code; p != null; p = p.getParent()) {
                candidates.add(p.resolve("plugins").resolve(PLUGIN_NAME + ".java"));
            }
        } catch (Exception ignored) {
            // no code source: nothing to add
        }
        return candidates.stream().filter(Files::isRegularFile).findFirst().orElse(null);
    }
}
