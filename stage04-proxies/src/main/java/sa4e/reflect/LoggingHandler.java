package sa4e.reflect;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.util.List;

/** Logs every call, its result or exception, and forwards it to the real object. */
public final class LoggingHandler implements InvocationHandler, Forwarding {

    private final Object target;
    private final List<String> log;

    public LoggingHandler(Object target, List<String> log) {
        this.target = target;
        this.log = log;
    }

    @Override
    public Object target() {
        return target;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        String call = Proxies.signature(method, args);
        log.add("→ " + call);
        try {
            Object result = Proxies.invokeTarget(target, method, args);
            log.add("← " + call + (method.getReturnType() == void.class ? "" : " = " + result));
            return result;
        } catch (Throwable t) {
            log.add("✗ " + call + " threw " + t.getClass().getSimpleName() + ": " + t.getMessage());
            throw t;
        }
    }
}
