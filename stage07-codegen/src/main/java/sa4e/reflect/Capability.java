package sa4e.reflect;

/**
 * The interface through which the outside world talks to Candidate from now on.
 * Dynamic proxies ({@code java.lang.reflect.Proxy}) can only implement interfaces, which is one
 * reason why enterprise frameworks ask for interfaces so often.
 */
public interface Capability {
    int getX();

    void f(int y, double d);
}
