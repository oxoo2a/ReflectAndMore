package sa4e.reflect;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.Arrays;

/** Small helpers shared by all invocation handlers. */
public final class Proxies {

    private Proxies() {}

    /** Creates a proxy that implements {@code type} and routes every call to {@code handler}. */
    @SuppressWarnings("unchecked")
    public static <T> T wrap(Class<T> type, InvocationHandler handler) {
        return (T) Proxy.newProxyInstance(type.getClassLoader(), new Class<?>[]{type}, handler);
    }

    /**
     * Forwards a call to the real object. The exception thrown by the target arrives wrapped in
     * an InvocationTargetException; unwrapping it is essential, otherwise the caller of the proxy
     * would see an UndeclaredThrowableException instead of the original exception.
     */
    public static Object invokeTarget(Object target, Method method, Object[] args) throws Throwable {
        try {
            return method.invoke(target, args);
        } catch (InvocationTargetException e) {
            throw e.getCause();
        }
    }

    /**
     * Follows a chain of proxies to the real object: as long as the object is a proxy whose
     * handler is {@link Forwarding}, continue with that handler's target. Spring's
     * {@code AopUtils.getTargetClass} does the same.
     */
    public static Object unwrap(Object object) {
        while (Proxy.isProxyClass(object.getClass())
                && Proxy.getInvocationHandler(object) instanceof Forwarding forwarding) {
            object = forwarding.target();
        }
        return object;
    }

    /**
     * The Method object handed to a handler belongs to the interface. Annotations such as
     * {@code @Transactional} or {@code @Range} are usually written on the implementing class, so
     * handlers look up the implementation's method with the same signature on the real object,
     * which may sit behind further proxies.
     */
    public static Method implementationMethod(Object target, Method interfaceMethod) {
        try {
            return unwrap(target).getClass().getMethod(interfaceMethod.getName(), interfaceMethod.getParameterTypes());
        } catch (NoSuchMethodException e) {
            return interfaceMethod;      // e.g. methods inherited from Object
        }
    }

    /** "f(3, -1.0)" for log messages. */
    public static String signature(Method method, Object[] args) {
        return method.getName() + "(" + (args == null ? "" : String.join(", ",
                Arrays.stream(args).map(String::valueOf).toList())) + ")";
    }
}
