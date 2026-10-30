package sa4e.reflect;

/**
 * Implemented by handlers that forward calls to another object. It lets
 * {@link Proxies#unwrap(Object)} follow a chain of proxies down to the real object, for
 * example to read annotations from its class.
 */
public interface Forwarding {
    Object target();
}
