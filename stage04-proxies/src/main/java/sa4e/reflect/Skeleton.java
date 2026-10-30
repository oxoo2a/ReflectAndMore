package sa4e.reflect;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

/**
 * Server side of a remote call: unmarshals the request, finds the method by name and parameter
 * types, invokes it on the real object and marshals the result or the error. This is what an
 * RMI skeleton, a SOAP endpoint or a REST controller adapter does.
 */
public final class Skeleton {

    private final Object target;

    public Skeleton(Object target) {
        this.target = target;
    }

    public String handle(String request) {
        try {
            String[] parts = request.split("\\|", -1);
            String name = parts[0];
            String[] typeNames = parts[1].isEmpty() ? new String[0] : parts[1].split(",");
            Class<?>[] types = new Class<?>[typeNames.length];
            Object[] args = new Object[typeNames.length];
            for (int i = 0; i < typeNames.length; i++) {
                types[i] = Wire.type(typeNames[i]);
                args[i] = Wire.decode(parts[2 + i]);
            }
            Method method = target.getClass().getMethod(name, types);
            Object result = method.invoke(target, args);
            return "ok|" + (method.getReturnType() == void.class ? "void" : Wire.encode(result));
        } catch (InvocationTargetException e) {
            return "error|" + e.getCause().getClass().getSimpleName() + ": " + e.getCause().getMessage();
        } catch (ReflectiveOperationException | RuntimeException e) {
            return "error|" + e.getClass().getSimpleName() + ": " + e.getMessage();
        }
    }
}
