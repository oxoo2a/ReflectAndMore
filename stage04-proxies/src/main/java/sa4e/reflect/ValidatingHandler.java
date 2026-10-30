package sa4e.reflect;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Parameter;

/**
 * Checks {@code @NotNull} and {@code @Range} on the parameters of the implementing method before
 * the call reaches the real object. The stage 03 validator checked fields after the fact; this
 * handler guards the entrance.
 */
public final class ValidatingHandler implements InvocationHandler, Forwarding {

    private final Object target;

    public ValidatingHandler(Object target) {
        this.target = target;
    }

    @Override
    public Object target() {
        return target;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        Parameter[] parameters = Proxies.implementationMethod(target, method).getParameters();
        for (int i = 0; i < parameters.length; i++) {
            Parameter p = parameters[i];
            Object value = args[i];
            if (p.isAnnotationPresent(NotNull.class) && value == null) {
                throw new IllegalArgumentException(p.getName() + " must not be null");
            }
            Range range = p.getAnnotation(Range.class);
            if (range != null && value instanceof Number number) {
                long v = number.longValue();
                if (v < range.min() || v > range.max()) {
                    throw new IllegalArgumentException(p.getName() + " = " + v + " is outside [" + range.min() + ", " + range.max() + "]");
                }
            }
        }
        return Proxies.invokeTarget(target, method, args);
    }
}
