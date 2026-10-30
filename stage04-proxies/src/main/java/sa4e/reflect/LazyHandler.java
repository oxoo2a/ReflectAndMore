package sa4e.reflect;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.util.function.Supplier;

/**
 * A virtual proxy: the real object is created on the first call. JPA providers hand out such
 * proxies for lazily loaded entities, and the database is hit only when a getter is called.
 */
public final class LazyHandler implements InvocationHandler {

    private final Supplier<?> factory;
    private Object target;

    public LazyHandler(Supplier<?> factory) {
        this.factory = factory;
    }

    public boolean isInitialized() {
        return target != null;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        if (target == null) target = factory.get();
        return Proxies.invokeTarget(target, method, args);
    }
}
