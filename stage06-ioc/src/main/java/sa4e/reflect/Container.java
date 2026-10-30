package sa4e.reflect;

import java.io.IOException;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.lang.reflect.Parameter;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;

/**
 * A dependency-injection container in about 150 lines.
 * <p>
 * It finds {@code @Component} classes by scanning, creates them on demand through the
 * {@code @Inject} constructor (or the no-arg constructor), resolves every constructor parameter
 * and every {@code @Inject} field from other components, fills {@code @Value} members from the
 * configuration, calls {@code @PostConstruct}, and keeps singletons unless the class is a
 * {@code @Prototype}. Every step is recorded in a trace, so Main can show what happened.
 */
public final class Container {

    private final Properties config;
    private final Map<String, Class<?>> components = new LinkedHashMap<>();   // name -> class
    private final Map<Class<?>, Object> singletons = new LinkedHashMap<>();
    private final Deque<Class<?>> inProgress = new ArrayDeque<>();            // for cycle detection
    private final List<String> trace = new ArrayList<>();

    public Container(Properties config) {
        this.config = config;
    }

    /** Registers every @Component class below the package. */
    public void scan(String basePackage) throws IOException {
        for (Class<?> c : ClassScanner.scan(basePackage, Container.class.getClassLoader())) {
            if (c.isAnnotationPresent(Component.class) && !c.isInterface() && !Modifier.isAbstract(c.getModifiers())) {
                components.put(nameOf(c), c);
            }
        }
        trace.add("scanned " + basePackage + ": " + components.size() + " components");
    }

    public Map<String, Class<?>> components() {
        return components;
    }

    public List<String> trace() {
        return trace;
    }

    public <T> T get(Class<T> type) {
        return get(type, null);
    }

    public <T> T get(Class<T> type, String name) {
        Class<?> implementation = resolve(type, name);
        return type.cast(instance(implementation));
    }

    // ---- resolution -------------------------------------------------------------------------

    /** Finds the one registered class that is assignable to the type (and has the name, if given). */
    private Class<?> resolve(Class<?> type, String name) {
        List<String> matches = new ArrayList<>();
        for (Map.Entry<String, Class<?>> e : components.entrySet()) {
            if (type.isAssignableFrom(e.getValue()) && (name == null || name.equals(e.getKey()))) {
                matches.add(e.getKey());
            }
        }
        String request = type.getSimpleName() + (name == null ? "" : " named '" + name + "'");
        if (matches.isEmpty()) throw new ContainerException("no component for " + request);
        if (matches.size() > 1) throw new ContainerException("ambiguous request for " + request + ": " + matches + "; use @Named");
        return components.get(matches.getFirst());
    }

    private Object instance(Class<?> implementation) {
        boolean prototype = implementation.isAnnotationPresent(Prototype.class);
        if (!prototype && singletons.containsKey(implementation)) {
            return singletons.get(implementation);
        }
        if (inProgress.contains(implementation)) {
            List<String> cycle = new ArrayList<>();
            inProgress.descendingIterator().forEachRemaining(c -> cycle.add(c.getSimpleName()));
            cycle.add(implementation.getSimpleName());
            throw new ContainerException("circular dependency: " + String.join(" -> ", cycle));
        }
        inProgress.push(implementation);
        try {
            Object object = construct(implementation);
            if (!prototype) singletons.put(implementation, object);   // registered before field injection: field cycles are fine
            injectFields(object);
            postConstruct(object);
            trace.add("ready: " + implementation.getSimpleName() + (prototype ? " (prototype)" : " (singleton)"));
            return object;
        } finally {
            inProgress.pop();
        }
    }

    // ---- construction -----------------------------------------------------------------------

    private Object construct(Class<?> implementation) {
        Constructor<?> constructor = chooseConstructor(implementation);
        Parameter[] parameters = constructor.getParameters();
        Object[] arguments = new Object[parameters.length];
        for (int i = 0; i < parameters.length; i++) {
            arguments[i] = valueFor(parameters[i].getType(), parameters[i], implementation.getSimpleName() + " parameter " + parameters[i].getName());
        }
        try {
            constructor.setAccessible(true);
            trace.add("construct " + implementation.getSimpleName() + " with " + parameters.length + " argument(s)");
            return constructor.newInstance(arguments);
        } catch (InvocationTargetException e) {
            throw new ContainerException("constructor of " + implementation.getSimpleName() + " threw " + e.getCause());
        } catch (ReflectiveOperationException e) {
            throw new ContainerException("cannot construct " + implementation.getSimpleName() + ": " + e);
        }
    }

    /** The @Inject constructor if there is one, otherwise the no-arg constructor. */
    private static Constructor<?> chooseConstructor(Class<?> implementation) {
        Constructor<?>[] constructors = implementation.getDeclaredConstructors();
        List<Constructor<?>> injectable = new ArrayList<>();
        for (Constructor<?> c : constructors) if (c.isAnnotationPresent(Inject.class)) injectable.add(c);
        if (injectable.size() > 1) throw new ContainerException(implementation.getSimpleName() + " has more than one @Inject constructor");
        if (injectable.size() == 1) return injectable.getFirst();
        for (Constructor<?> c : constructors) if (c.getParameterCount() == 0) return c;
        throw new ContainerException(implementation.getSimpleName() + " needs an @Inject constructor or a no-arg constructor");
    }

    private void injectFields(Object object) {
        for (Class<?> k = object.getClass(); k != null; k = k.getSuperclass()) {
            for (Field f : k.getDeclaredFields()) {
                if (!f.isAnnotationPresent(Inject.class) && !f.isAnnotationPresent(Value.class)) continue;
                Object value = valueFor(f.getType(), f, k.getSimpleName() + "." + f.getName());
                try {
                    f.setAccessible(true);
                    f.set(object, value);
                    trace.add("inject " + k.getSimpleName() + "." + f.getName() + " = " + describe(value));
                } catch (IllegalAccessException e) {
                    throw new ContainerException("cannot inject " + f + ": " + e);
                }
            }
        }
    }

    private void postConstruct(Object object) {
        for (Class<?> k = object.getClass(); k != null; k = k.getSuperclass()) {
            for (Method m : k.getDeclaredMethods()) {
                if (!m.isAnnotationPresent(PostConstruct.class)) continue;
                try {
                    m.setAccessible(true);
                    m.invoke(object);
                    trace.add("post-construct " + k.getSimpleName() + "." + m.getName() + "()");
                } catch (ReflectiveOperationException e) {
                    throw new ContainerException("post-construct of " + k.getSimpleName() + " failed: " + e);
                }
            }
        }
    }

    /** What goes into a parameter or field: a configuration value, or another component. */
    private Object valueFor(Class<?> type, java.lang.reflect.AnnotatedElement element, String where) {
        Value value = element.getAnnotation(Value.class);
        if (value != null) {
            String key = value.value().replaceAll("^\\$\\{|}$", "");
            String raw = config.getProperty(key);
            if (raw == null) throw new ContainerException("no configuration value '" + key + "' for " + where);
            trace.add("config " + where + " = " + raw);
            return convert(raw, type);
        }
        Named named = element.getAnnotation(Named.class);
        return instance(resolve(type, named == null ? null : named.value()));
    }

    private static Object convert(String raw, Class<?> type) {
        if (type == String.class) return raw;
        if (type == int.class || type == Integer.class) return Integer.parseInt(raw);
        if (type == long.class || type == Long.class) return Long.parseLong(raw);
        if (type == double.class || type == Double.class) return Double.parseDouble(raw);
        if (type == boolean.class || type == Boolean.class) return Boolean.parseBoolean(raw);
        throw new ContainerException("cannot convert '" + raw + "' to " + type.getSimpleName());
    }

    static String nameOf(Class<?> c) {
        String explicit = c.getAnnotation(Component.class).value();
        if (!explicit.isEmpty()) return explicit;
        String simple = c.getSimpleName();
        return Character.toLowerCase(simple.charAt(0)) + simple.substring(1);
    }

    private static String describe(Object value) {
        return value == null ? "null" : "the " + value.getClass().getSimpleName() + " instance";
    }
}
