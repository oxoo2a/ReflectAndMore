package sa4e.reflect;

import java.io.IOException;
import java.lang.reflect.Proxy;
import java.lang.reflect.UndeclaredThrowableException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Stage 04: dynamic proxies.
 * <p>
 * A proxy is an object that implements an interface without having a class written for it.
 * Every call on the proxy becomes one call of {@code InvocationHandler.invoke(proxy, method, args)},
 * and the handler decides what happens: forward it, log it, validate it, wrap it in a
 * transaction, send it over a network, or create the real object first.
 */
public final class Main {

    /** The hand-written way: one such class per interface and per concern. */
    static final class LoggingCapability implements Capability {
        private final Capability target;
        private final List<String> log;

        LoggingCapability(Capability target, List<String> log) {
            this.target = target;
            this.log = log;
        }

        @Override
        public int getX() {
            log.add("getX()");
            return target.getX();
        }

        @Override
        public void f(int y, double d) {
            log.add("f(" + y + ", " + d + ")");
            target.f(y, d);
        }
    }

    public static void main(String[] args) throws Exception {
        Report r = Report.stdout();
        r.title("Stage 04: dynamic proxies");

        r.heading("1. The pain: a decorator per interface and per concern");
        List<String> log = new ArrayList<>();
        Capability decorated = new LoggingCapability(new Candidate(7), log);
        decorated.f(3, -1.0);
        r.kv("new LoggingCapability(new Candidate(7), log).f(3, -1.0); getX()", decorated.getX());
        r.kv("log", log);
        r.note("LoggingCapability works, but it knows Capability. Logging for a second interface means a second class, "
                + "and a second concern (transactions, security, caching) means a class for every interface again.");

        r.heading("2. The same with a dynamic proxy: one handler for all interfaces");
        log.clear();
        Candidate real = new Candidate(7);
        Capability proxy = Proxies.wrap(Capability.class, new LoggingHandler(real, log));
        proxy.f(3, -1.0);
        r.kv("proxy.f(3, -1.0); proxy.getX()", proxy.getX());
        r.kv("proxy.toString()", proxy.toString());
        r.kv("log", log);
        r.kv("proxy.getClass().getName()", proxy.getClass().getName());
        r.kv("Proxy.isProxyClass(proxy.getClass())", Proxy.isProxyClass(proxy.getClass()));
        r.kv("proxy.getClass().getInterfaces()", Arrays.toString(proxy.getClass().getInterfaces()));
        r.kv("proxy instanceof Capability", proxy instanceof Capability);
        r.kv("proxy instanceof Candidate", proxy instanceof Candidate);
        r.note("Proxy.newProxyInstance generates a class at run time that implements the interface. Each method "
                + "of that class does nothing but call handler.invoke(this, method, args). Even toString() goes "
                + "through the handler, which is why it appears in the log.");

        r.heading("3. What the generated class looks like");
        r.code("xml", new Inspector(proxy.getClass()).describe());
        r.note("The Inspector from stage 02 works on the generated class as on any other: it is final, extends "
                + "java.lang.reflect.Proxy (which holds the handler in field h), and caches the Method objects it "
                + "passes to the handler in static fields m0, m1, ...");

        r.heading("4. A chain of handlers: logging, transactions, validation");
        log.clear();
        TransactionLog tx = new TransactionLog();
        Capability validated = Proxies.wrap(Capability.class, new ValidatingHandler(real));
        Capability transactional = Proxies.wrap(Capability.class, new TransactionalHandler(validated, tx));
        Capability chained = Proxies.wrap(Capability.class, new LoggingHandler(transactional, log));
        chained.f(5, 1.0);
        r.kv("chained.f(5, 1.0); chained.getX()", chained.getX());
        try {
            chained.f(1000, 1.0);
        } catch (IllegalArgumentException e) {
            r.kv("chained.f(1000, 1.0)", "IllegalArgumentException: " + e.getMessage());
        }
        r.kv("real.getX() afterwards", real.getX());
        r.kv("log", log);
        r.kv("tx.entries()", tx.entries());
        r.note("Each proxy forwards to the next; the real object is reached last and knows nothing about any of it. "
                + "f is @Transactional and getX is not, so only f produces begin/commit. The invalid call is rejected "
                + "by the validating handler, the transaction is rolled back, and the logging handler records the "
                + "exception. This is the EJB container and Spring AOP in three classes.");

        r.heading("5. Where do the annotations live?");
        r.kv("Capability.class.getMethod(\"f\", ...).isAnnotationPresent(Transactional.class)",
                Capability.class.getMethod("f", int.class, double.class).isAnnotationPresent(Transactional.class));
        r.kv("Candidate.class.getMethod(\"f\", ...).isAnnotationPresent(Transactional.class)",
                Candidate.class.getMethod("f", int.class, double.class).isAnnotationPresent(Transactional.class));
        r.kv("Proxies.unwrap(chained) == real", Proxies.unwrap(chained) == real);
        r.kv("Proxies.unwrap(chained).getClass()", Proxies.unwrap(chained).getClass().getSimpleName());
        r.note("The Method handed to a handler belongs to the interface, where nothing is annotated. The handlers "
                + "therefore look up the implementing method on the real object's class. In a chain the next object "
                + "is itself a proxy, so Proxies.unwrap follows the handlers' targets down to Candidate first. "
                + "Spring does the same (AopUtils.getTargetClass) and documents that annotations on interfaces are "
                + "not always honoured.");

        r.heading("6. A virtual proxy: the real object is created on first use");
        int before = Candidate.created();
        LazyHandler lazy = new LazyHandler(() -> new Candidate(9));
        Capability lazyProxy = Proxies.wrap(Capability.class, lazy);
        r.kv("after creating the lazy proxy: lazy.isInitialized()", lazy.isInitialized());
        r.kv("Candidate.created() unchanged", Candidate.created() == before);
        r.kv("lazyProxy.getX()", lazyProxy.getX());
        r.kv("now lazy.isInitialized()", lazy.isInitialized());
        r.note("JPA entities with lazy associations are proxies like this: the database is queried the moment "
                + "the first getter is called, which is also why LazyInitializationException exists.");

        r.heading("7. A remote stub: the handler sends the call somewhere else");
        List<String> wire = new ArrayList<>();
        Skeleton server = new Skeleton(chained);                          // server side: skeleton -> interceptors -> Candidate
        Capability stub = RemoteStub.create(Capability.class, server::handle, wire);
        log.clear();
        stub.f(2, -1.0);
        r.kv("stub.f(2, -1.0); stub.getX()", stub.getX());
        try {
            stub.f(1000, 1.0);
        } catch (RuntimeException e) {
            r.kv("stub.f(1000, 1.0)", e.getMessage());
        }
        r.kv("stub.toString()", stub.toString());
        r.kv("wire", wire);
        r.kv("server-side log", log);
        r.note("The stub marshals the call into a string, the skeleton unmarshals it, finds the method by name and "
                + "parameter types and invokes it reflectively. Replace the Function<String,String> with a socket "
                + "or HTTP and this is RMI, SOAP or a REST client. The server side reuses the interceptor chain "
                + "from section 4: that is the EJB container picture, stub, skeleton, container services, bean.");

        r.heading("8. Pitfalls");
        Capability throwing = Proxies.wrap(Capability.class, (p, m, a) -> {
            throw new IOException("checked exception from the handler");
        });
        try {
            throwing.getX();
        } catch (UndeclaredThrowableException e) {
            r.kv("handler throws IOException, getX() declares none", "UndeclaredThrowableException wrapping " + e.getCause());
        }
        try {
            Proxies.wrap(Candidate.class, (p, m, a) -> null);
        } catch (IllegalArgumentException e) {
            r.kv("Proxies.wrap(Candidate.class, ...)", "IllegalArgumentException: " + e.getMessage());
        }
        r.item("Only interfaces: a proxy cannot stand in for a class. Frameworks generate subclasses for that (stage 07).");
        r.item("Self-invocation: if Candidate.f called this.getX(), the call would bypass every handler. "
                + "Spring's most frequently asked @Transactional question is exactly this.");
        r.item("Identity: proxy != real, so equals and hashCode must be thought through.");
        r.item("Checked exceptions not declared by the interface method are wrapped in UndeclaredThrowableException.");
        r.flush();
    }
}
