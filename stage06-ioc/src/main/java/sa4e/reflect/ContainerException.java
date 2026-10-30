package sa4e.reflect;

/** Thrown when the container cannot satisfy a request: unknown, ambiguous or circular. */
public final class ContainerException extends RuntimeException {
    public ContainerException(String message) {
        super(message);
    }
}
