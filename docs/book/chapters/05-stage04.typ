#import "../template.typ": *

#chapter(num: "Stage 04", title: "Dynamic proxies", tagline: [In which an object implements an interface nobody wrote a class for, and we build an EJB container in three handlers.])

== Where we stand

Stage 03 ended with a `@Transactional`-shaped hole. Annotations can _declare_ that something should happen around a method call, but somebody has to make it happen, and the obvious way does not scale. To log every call on an interface you write a decorator class that implements the interface and forwards every method. To add transactions you write another. To add security, caching, metrics, retries, you write another each. And you do it again for every interface. The number of classes is the product of interfaces and concerns, and every one of them is boilerplate that forwards calls.

Stage 04 replaces all of them with a single mechanism. `java.lang.reflect.Proxy` generates, at run time, a class that implements any interface you name, and routes every call on it to one method of your choosing. From there, logging, validation, transactions, lazy loading and even remote calls are each one short class.

== The pain, concretely

Stage 04 gives `Candidate` an interface, because proxies need one:

```java
public interface Capability {
    int getX();
    void f(int y, double d);
}

public class Candidate implements Capability {
    // ...
    @Override
    @Transactional
    public void f(@Range(min = -10, max = 10) int y, double d) { /* unchanged */ }
}
```

and shows the hand-written way once, so that the next section has something to beat:

```java
static final class LoggingCapability implements Capability {
    private final Capability target;
    private final List<String> log;

    LoggingCapability(Capability target, List<String> log) {
        this.target = target;
        this.log = log;
    }

    @Override public int getX() {
        log.add("getX()");
        return target.getX();
    }

    @Override public void f(int y, double d) {
        log.add("f(" + y + ", " + d + ")");
        target.f(y, d);
    }
}
```

#results(
  ("new LoggingCapability(new Candidate(7), log).f(3, -1.0); getX()", "3"),
  ("log", "[f(3, -1.0), getX()]"),
)

It works. It also knows `Capability` by name, mentions both of its methods, and would need to be rewritten for every other interface and every other concern. Multiply by a real project's fifty interfaces and six cross-cutting concerns, and the decorator pattern becomes three hundred classes of pure forwarding.

== One handler for all interfaces

```java
public final class LoggingHandler implements InvocationHandler {
    private final Object target;
    private final List<String> log;

    public LoggingHandler(Object target, List<String> log) {
        this.target = target;
        this.log = log;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        String call = Proxies.signature(method, args);          // "f(3, -1.0)"
        log.add("→ " + call);
        try {
            Object result = Proxies.invokeTarget(target, method, args);
            boolean isVoid = method.getReturnType() == void.class;
            log.add("← " + call + (isVoid ? "" : " = " + result));
            return result;
        } catch (Throwable t) {
            log.add("✗ " + call + " threw " + t.getClass().getSimpleName()
                    + ": " + t.getMessage());
            throw t;
        }
    }
}
```
#src[stage04-proxies/src/main/java/sa4e/reflect/LoggingHandler.java]

```java
Candidate real = new Candidate(7);
Capability proxy = Proxies.wrap(Capability.class, new LoggingHandler(real, log));
proxy.f(3, -1.0);
```

where `Proxies.wrap` is the one line that matters in the whole chapter:

```java
public static <T> T wrap(Class<T> type, InvocationHandler handler) {
    return (T) Proxy.newProxyInstance(type.getClassLoader(), new Class<?>[]{type}, handler);
}
```

#results(
  ("proxy.f(3, -1.0); proxy.getX()", "3"),
  ("proxy.toString()", "Candidate{x=3, label='candidate#7'}"),
  ("log", "[→ f(3, -1.0), ← f(3, -1.0), → getX(), ← getX() = 3, → toString(), ← toString() = Candidate{...}]"),
  ("proxy.getClass().getName()", "jdk.proxy1.$Proxy0"),
  ("Proxy.isProxyClass(proxy.getClass())", "true"),
  ("proxy.getClass().getInterfaces()", "[interface sa4e.reflect.Capability]"),
  ("proxy instanceof Capability", "true"),
  ("proxy instanceof Candidate", "false"),
)

Read the handler and the results together. `LoggingHandler` does not mention `Capability`, `getX` or `f`. It has one method, `invoke`, and the JVM calls that method for _every_ method of _every_ interface the proxy implements, passing the `Method` object from stage 02 and the arguments as an `Object[]`. The handler logs, forwards with `Method.invoke`, logs again, and returns whatever came back. The same handler class would log calls on `java.sql.Connection` or on `Runnable` without a single change.

`Proxy.newProxyInstance` is where the class comes from. Given a class loader, a list of interfaces and a handler, it generates a class at run time, in a package called `jdk.proxy1`, with a name like `$Proxy0`, that implements the interfaces and whose every method is a stub calling `handler.invoke(this, method, args)`. Note `proxy instanceof Candidate` is `false`: the proxy is not a `Candidate` wearing a disguise, it is a brand-new class that happens to implement the same interface. That is why the interface was needed.

And note that `toString()` went through the handler too. The proxy class overrides `equals`, `hashCode` and `toString` and routes them to the handler like everything else, which is sometimes exactly what you want (here the log shows it) and sometimes a surprise (a handler that forwards to a remote server will make `System.out.println(proxy)` do a network round trip).

== What the generated class looks like

We have an `Inspector`, the class-describing tool from stage 02. Let us point it at the proxy class:

```xml
<class name="jdk.proxy1.$Proxy0" modifiers="public final"
       superclass="java.lang.reflect.Proxy">
  <constructor modifiers="public">
    <parameter name="arg0" type="java.lang.reflect.InvocationHandler"/>
  </constructor>
  <field name="m0" type="java.lang.reflect.Method" modifiers="private static final"/>
  <field name="m1" type="java.lang.reflect.Method" modifiers="private static final"/>
  <field name="m2" type="java.lang.reflect.Method" modifiers="private static final"/>
  <field name="m3" type="java.lang.reflect.Method" modifiers="private static final"/>
  <field name="m4" type="java.lang.reflect.Method" modifiers="private static final"/>
  <method name="equals" modifiers="public final" returns="boolean">
    <parameter name="arg0" type="java.lang.Object"/>
  </method>
  <method name="f" modifiers="public final" returns="void">
    <parameter name="arg0" type="int"/>
    <parameter name="arg1" type="double"/>
  </method>
  <method name="getX" modifiers="public final" returns="int">
  </method>
  <method name="hashCode" modifiers="public final" returns="int">
  </method>
  <method name="toString" modifiers="public final" returns="java.lang.String">
  </method>
</class>
```

Everything about the mechanism is visible. The class is `final` and extends `java.lang.reflect.Proxy`, which holds the handler in a field `h`. Its single constructor takes the handler. It caches the five `Method` objects it will pass to the handler (two from `Capability`, three from `Object`) in static fields `m0` to `m4`, so that `invoke` does not have to look them up on every call. The parameter names are `arg0`, `arg1`: the generated class was not compiled with `-parameters`, because it was not compiled at all. Stage 07 writes a class like this by hand.

== A chain of handlers

Handlers compose, because a handler's target can itself be a proxy. Stage 04 adds two more handlers and stacks them:

```java
TransactionLog tx = new TransactionLog();
Capability validated = Proxies.wrap(Capability.class,
        new ValidatingHandler(real));
Capability transactional = Proxies.wrap(Capability.class,
        new TransactionalHandler(validated, tx));
Capability chained = Proxies.wrap(Capability.class,
        new LoggingHandler(transactional, log));
```

```
caller ──▶ LoggingHandler ──▶ TransactionalHandler ──▶ ValidatingHandler ──▶ Candidate
            ($Proxy2)             ($Proxy1)               ($Proxy0)          (real)
```

`ValidatingHandler` checks `@NotNull` and `@Range` on the _parameters_ of the implementing method before the call goes through, the stage 03 validator moved from after-the-fact to the entrance. `TransactionalHandler` is the one everyone has been waiting for since stage 03:

```java
@Override
public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
    Method implementation = Proxies.implementationMethod(target, method);
    if (!implementation.isAnnotationPresent(Transactional.class)) {
        return Proxies.invokeTarget(target, method, args);       // not our business
    }
    int tx = transactions.begin(Proxies.signature(method, args));
    try {
        Object result = Proxies.invokeTarget(target, method, args);
        transactions.commit(tx);
        return result;
    } catch (Throwable t) {
        transactions.rollback(tx, t);
        throw t;
    }
}
```
#src[stage04-proxies/src/main/java/sa4e/reflect/TransactionalHandler.java]

`TransactionLog` stands in for a transaction manager and merely records what it was asked to do. One good call and one bad call through the chain:

#results(
  ("chained.f(5, 1.0); chained.getX()", "-5"),
  ("chained.f(1000, 1.0)", "IllegalArgumentException: y = 1000 is outside [-10, 10]"),
  ("real.getX() afterwards", "-5"),
  ("log", "[→ f(5, 1.0), ← f(5, 1.0), → getX(), ← getX() = -5, → f(1000, 1.0), ✗ f(1000, 1.0) threw IllegalArgumentException: y = 1000 is outside [-10, 10]]"),
  ("tx.entries()", "[begin tx1 for f(5, 1.0), commit tx1, begin tx2 for f(1000, 1.0), rollback tx2 because of IllegalArgumentException]"),
)

Follow the second call through the picture. The logging handler records the entry and forwards. The transactional handler sees `@Transactional` on `f`, begins `tx2` and forwards. The validating handler reads `@Range(min = -10, max = 10)` on parameter `y`, finds 1000, and throws. The exception travels back: the transactional handler rolls back `tx2` and rethrows, the logging handler records the failure and rethrows, the caller catches an `IllegalArgumentException`. `Candidate` was never reached, its `x` is still `-5`, and `Candidate` contains not one line about logging, validation or transactions.

That is an EJB container. That is Spring AOP. `getX` is not `@Transactional`, so it passes the middle handler untouched; a real container would also have security, metrics and a dozen other handlers in the chain, each deciding for itself whether a call is its business.

=== A detail that bit us

`Proxies.invokeTarget` deserves its own paragraph, because the first version of this stage got it wrong:

```java
public static Object invokeTarget(Object target, Method method, Object[] args)
        throws Throwable {
    try {
        return method.invoke(target, args);
    } catch (InvocationTargetException e) {
        throw e.getCause();                         // essential: unwrap
    }
}
```

Stage 02 warned that `Method.invoke` wraps exceptions in `InvocationTargetException`. In a handler, forgetting to unwrap has a nasty consequence: the proxy's generated method sees a checked exception that the interface method did not declare and wraps it _again_, in an `UndeclaredThrowableException`. The caller then catches an `UndeclaredThrowableException` wrapping an `InvocationTargetException` wrapping the `IllegalArgumentException` it actually wanted. Every proxy-based framework has this unwrapping in one central place.

== Where do the annotations live?

The second thing the first version of this stage got wrong is worth a section of its own, because it is a question every framework author has had to answer:

#results(
  ("Capability.class.getMethod(\"f\", ...).isAnnotationPresent(Transactional.class)", "false"),
  ("Candidate.class.getMethod(\"f\", ...).isAnnotationPresent(Transactional.class)", "true"),
  ("Proxies.unwrap(chained) == real", "true"),
  ("Proxies.unwrap(chained).getClass()", "Candidate"),
)

The `Method` object a handler receives belongs to the _interface_, `Capability.f`, and there is no `@Transactional` on the interface. The annotation is on the implementation, `Candidate.f`. So a handler must look up the method with the same name and parameter types on the class of the real object. And in a chain, the handler's target is not the real object but the next proxy, whose class is `$Proxy0` and carries no annotations either. The first version of `TransactionalHandler` looked there, found nothing, and the transaction log stayed empty.

The fix is `Proxies.unwrap`, which follows the chain down:

```java
public static Object unwrap(Object object) {
    while (Proxy.isProxyClass(object.getClass())
            && Proxy.getInvocationHandler(object) instanceof Forwarding forwarding) {
        object = forwarding.target();
    }
    return object;
}
```

Handlers that forward implement a tiny `Forwarding` interface with one method, `target()`, so that the chain can be walked. Spring has the same method, `AopUtils.getTargetClass`, for the same reason, and its documentation warns, as ours now does, that annotations on interfaces are not always honoured.

== A virtual proxy

Not every handler forwards to an object that already exists:

```java
public final class LazyHandler implements InvocationHandler {
    private final Supplier<?> factory;
    private Object target;

    public LazyHandler(Supplier<?> factory) { this.factory = factory; }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        if (target == null) target = factory.get();   // first call creates the target
        return Proxies.invokeTarget(target, method, args);
    }
}
```

#results(
  ("after creating the lazy proxy: lazy.isInitialized()", "false"),
  ("Candidate.created() unchanged", "true"),
  ("lazyProxy.getX()", "9"),
  ("now lazy.isInitialized()", "true"),
)

This is the _virtual proxy_ of the Gang of Four book, and it is how a JPA provider implements lazy loading. When you load an `Order`, its `customer` field holds a proxy, not a `Customer`; the database is queried the moment the first getter is called. It is also why `LazyInitializationException` exists: if the first getter is called after the session that could run the query has been closed, the factory has nowhere to go.

== A remote stub

The last handler does not forward to an object at all. It forwards to _somewhere else_:

```java
public static <T> T create(Class<T> type, Function<String, String> transport,
                           List<String> wireLog) {
    return Proxies.wrap(type, (proxy, method, args) -> {
        if (method.getDeclaringClass() == Object.class) {        // toString etc. stay local
            return "RemoteStub[" + type.getSimpleName() + "]";
        }
        String request = marshal(method, args);      // "f|int,double|int:2|double:-1.0"
        wireLog.add("request: " + request);
        String reply = transport.apply(request);
        wireLog.add("reply:   " + reply);
        return unmarshal(reply);                                 // "ok|int:2" -> 2
    });
}
```
#src[stage04-proxies/src/main/java/sa4e/reflect/RemoteStub.java (abridged)]

On the other side of the transport sits a `Skeleton`, which does the reverse: split the request, map the type names back to classes, find the method with `getMethod(name, types)`, invoke it on the real object, and marshal the result or the error. For the demo the transport is a method call, `server::handle`, but it could be a socket or an HTTP client without changing a line of the stub.

#results(
  ("stub.f(2, -1.0); stub.getX()", "2"),
  ("stub.f(1000, 1.0)", "remote: IllegalArgumentException: y = 1000 is outside [-10, 10]"),
  ("stub.toString()", "RemoteStub[Capability]"),
  ("wire", "[request: f|int,double|int:2|double:-1.0, reply: ok|void, request: getX|, reply: ok|int:2, request: f|int,double|int:1000|double:1.0, reply: error|IllegalArgumentException: y = 1000 is outside [-10, 10]]"),
)

This is Java RMI. It is also a CORBA stub, a SOAP client proxy, and what Feign and Retrofit do with annotated interfaces over HTTP. The toy wire format, `type:value` joined by bars, stands in for XDR, IIOP, JSON or Protocol Buffers; the shape of the mechanism is identical. And look at what the skeleton's real object was in the demo: `chained`, the interceptor chain from before. The third request was rejected by the validating handler on the server side, rolled back by the transactional handler, and the error travelled back over the wire. Stub, skeleton, container services, bean. That picture is the whole of lecture 5 in one line of code.

== Pitfalls

#results(
  ("handler throws IOException, getX() declares none", "UndeclaredThrowableException wrapping java.io.IOException: checked exception from the handler"),
  ("Proxies.wrap(Candidate.class, ...)", "IllegalArgumentException: sa4e.reflect.Candidate is not an interface"),
)

- *Interfaces only.* A JDK proxy cannot stand in for a class. Frameworks that must intercept a class without an interface generate a subclass instead, with CGLIB or ByteBuddy; stage 07 does it by hand.
- *Self-invocation.* If `Candidate.f` called `this.getX()`, that call would go straight to the real object and bypass every handler. The proxy only sees calls that come from outside. Spring's most frequently asked `@Transactional` question is exactly this: "why is my transaction not started when one method of my service calls another?"
- *Identity.* `proxy != real`, `proxy.getClass() != Candidate.class`, and `equals` goes through the handler. Collections of proxies, caches keyed by object and `instanceof` checks all need thought.
- *Checked exceptions.* A handler that throws a checked exception the interface method does not declare produces an `UndeclaredThrowableException`. Unwrap `InvocationTargetException`, and only throw what the interface allows.
- *Stack traces.* Every call now has `$Proxy0.f`, `LoggingHandler.invoke`, `Method.invoke` and a few JDK frames in it. The breakpoint in `Candidate.f` is still hit; the question "who called me?" has a longer answer.

#wild[
  - EJB containers and Spring AOP: the handler chain is container-managed transactions, declarative security, interceptors and aspects. Spring creates exactly these JDK proxies for beans that implement interfaces, and CGLIB subclasses otherwise.
  - Java RMI, CORBA, SOAP client proxies, Feign, Retrofit, gRPC stubs: the remote stub with a real transport and a real marshalling format.
  - Hibernate and other JPA providers: the virtual proxy, for lazy associations.
  - Annotation instances (stage 03), `java.sql.Connection` wrappers from connection pools, Mockito mocks of interfaces, and `java.lang.reflect.Proxy`'s own test suite.
]

#bill[
  - One reflective call per invocation, with stage 02's overhead; proxies are not for hot inner loops.
  - Interfaces only; subclass generation is a separate, heavier mechanism.
  - Self-invocation bypasses everything, `equals`/`hashCode`/`getClass` lie a little, and stack traces grow.
  - Every handler is a place where behaviour happens that is written nowhere near the code it affects. Debugging "why did this call take 200 ms" now means reading the chain.
]

#tryit[
  + Add a `CachingHandler` that remembers the result of `getX()` until the next call of `f`.
  + Let `LoggingHandler` measure each call in microseconds and log it.
  + Extend `Wire` and `Skeleton` so that methods can take and return `String` arrays, then write down what would have to change for arbitrary objects. (You are designing a serialization format. Stop when you notice.)
  + Make the stub talk over a real `java.net.ServerSocket` in a second thread.
]

#takeaway[
  - `Proxy.newProxyInstance` generates a class that implements interfaces and routes every call to `InvocationHandler.invoke(proxy, method, args)`.
  - One handler serves every interface; concerns become handlers, and handlers chain.
  - Always unwrap `InvocationTargetException`; always look for annotations on the real class, through the chain.
  - A virtual proxy creates its target on first use; a remote stub has no local target at all.
  - Interfaces only, and self-invocation bypasses the proxy. Both limits shape how frameworks ask you to write code.
]
