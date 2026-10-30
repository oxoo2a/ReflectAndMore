package sa4e.reflect;

import java.lang.invoke.MethodType;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Arrays;

/**
 * Convenience layer over the raw reflection API: create objects, call methods and access fields
 * by name, with the member chosen by the run-time types of the arguments.
 * <p>
 * The raw API ({@code getDeclaredMethod(name, parameterTypes...)}) needs the exact parameter
 * types; this class searches for a compatible member instead, the way scripting engines,
 * expression languages and test frameworks do it. Private members are reached with
 * {@code setAccessible(true)}, which works for our own classes but not for the JDK's.
 */
public final class Invoker {

    private Invoker() {}

    /** Creates an instance of the named class with whichever constructor accepts the arguments. */
    public static Object newInstance(String className, Object... args) throws ReflectiveOperationException {
        Class<?> type = Class.forName(className);
        for (Constructor<?> ctor : type.getDeclaredConstructors()) {
            if (matches(ctor.getParameterTypes(), args)) {
                ctor.setAccessible(true);
                return ctor.newInstance(args);
            }
        }
        throw new NoSuchMethodException("no constructor of " + className + " accepts " + Arrays.toString(args));
    }

    /**
     * Calls a method by name. Pass an object for instance methods, or a {@link Class} for static
     * methods. Inherited and private methods are found as well.
     */
    public static Object call(Object target, String name, Object... args) throws ReflectiveOperationException {
        boolean isStatic = target instanceof Class<?>;
        Class<?> type = isStatic ? (Class<?>) target : target.getClass();
        for (Class<?> k = type; k != null; k = k.getSuperclass()) {
            for (Method m : k.getDeclaredMethods()) {
                if (m.getName().equals(name) && matches(m.getParameterTypes(), args)) {
                    m.setAccessible(true);
                    return m.invoke(isStatic ? null : target, args);
                }
            }
        }
        throw new NoSuchMethodException(type.getName() + "." + name + " accepting " + Arrays.toString(args));
    }

    public static Object get(Object target, String fieldName) throws ReflectiveOperationException {
        Field f = findField(target, fieldName);
        return f.get(target instanceof Class<?> ? null : target);
    }

    public static void set(Object target, String fieldName, Object value) throws ReflectiveOperationException {
        Field f = findField(target, fieldName);
        f.set(target instanceof Class<?> ? null : target, value);
    }

    private static Field findField(Object target, String name) throws NoSuchFieldException {
        Class<?> type = target instanceof Class<?> k ? k : target.getClass();
        for (Class<?> k = type; k != null; k = k.getSuperclass()) {
            for (Field f : k.getDeclaredFields()) {
                if (f.getName().equals(name)) {
                    f.setAccessible(true);
                    return f;
                }
            }
        }
        throw new NoSuchFieldException(type.getName() + "." + name);
    }

    /** True if every argument can be passed to the corresponding parameter (boxing included). */
    private static boolean matches(Class<?>[] parameterTypes, Object[] args) {
        if (parameterTypes.length != args.length) return false;
        for (int i = 0; i < args.length; i++) {
            if (args[i] == null) {
                if (parameterTypes[i].isPrimitive()) return false;   // null cannot become an int
                continue;
            }
            if (!wrap(parameterTypes[i]).isInstance(args[i])) return false;
        }
        return true;
    }

    /** int.class -> Integer.class etc.; non-primitive types are returned unchanged. */
    private static Class<?> wrap(Class<?> type) {
        return type.isPrimitive() ? MethodType.methodType(type).wrap().returnType() : type;
    }
}
