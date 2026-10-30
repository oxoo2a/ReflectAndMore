# Stage 04: dynamic proxies

## Pain in stage 03

Annotations such as `@Transactional` declare that something should happen around a method
call, but somebody has to make it happen. Writing a decorator class per interface and per
concern (logging, validation, transactions, security, caching) does not scale: the number of
classes is the product of the two.

## Mechanism

`java.lang.reflect.Proxy` generates, at run time, a class that implements any list of
interfaces. Every method of that class forwards to one `InvocationHandler.invoke(proxy, method, args)`.
The handler is ordinary code that receives the `Method` object and the arguments and decides
what to do: forward, log, validate, begin a transaction, send the call across a network, or
create the real object first.

`Main` walks through:

1. the hand-written decorator and why it does not scale
2. the first dynamic proxy, and what `Proxy.newProxyInstance` returns
3. the generated proxy class, described by the `Inspector` from stage 02
4. a chain of handlers: logging around transactions around validation around `Candidate`,
   with a committed and a rolled-back call
5. where the annotations live: on the implementation, not on the interface, and how a chain
   of proxies is unwrapped to find it
6. a virtual proxy that creates `Candidate` on the first call (JPA lazy loading)
7. a remote stub and skeleton that marshal the call into a string and back
8. pitfalls: checked exceptions, classes instead of interfaces, self-invocation, identity

## New files

| File | Purpose |
|---|---|
| `Capability.java` | the interface `Candidate` implements from now on |
| `Transactional.java` | marks methods that need a transaction |
| `Proxies.java` | `wrap`, `invokeTarget` (exception unwrapping), `unwrap` (proxy chains), `implementationMethod` |
| `Forwarding.java` | implemented by handlers that forward to a target, so chains can be unwrapped |
| `LoggingHandler.java` | logs calls, results and exceptions |
| `ValidatingHandler.java` | checks `@NotNull` and `@Range` on parameters before the call |
| `TransactionalHandler.java`, `TransactionLog.java` | begin, commit, rollback around `@Transactional` methods |
| `LazyHandler.java` | a virtual proxy creating the target on first use |
| `RemoteStub.java`, `Skeleton.java`, `Wire.java` | client stub, server skeleton and a toy wire format |

Changed: `Candidate` implements `Capability` and `f` is `@Transactional`. The validator and the
test runner of stage 03 are no longer needed and were dropped; the annotation types
`Comment`, `Marker`, `NotNull` and `Range` stay because `Candidate` uses them.

## In the real world

- EJB containers and Spring AOP: section 4 is container-managed transactions, declarative
  security and interceptors; Spring creates exactly such JDK proxies for beans that implement
  interfaces.
- Java RMI, CORBA, SOAP client proxies, Feign and Retrofit: section 7 with a real transport
  and a real marshalling format.
- Hibernate and other JPA providers: section 6 for lazy associations.
- Annotation instances (stage 03, section 6) and `java.sql.Connection` pooling wrappers are
  proxies too.

## Cost

- One extra reflective call per invocation, with the overhead measured in stage 02.
- Interfaces only; proxying a class requires generated subclasses (CGLIB, ByteBuddy, stage 07).
- Self-invocation bypasses the proxy, stack traces grow by several frames, and `equals`,
  `hashCode` and `getClass()` no longer behave as naively expected.
- Debugging: breakpoints inside `Candidate` are hit, but who called is now a chain of handlers.

## Exercises

1. Add a `CachingHandler` that remembers the result of `getX()` until the next call of `f`.
2. Let `LoggingHandler` measure the time of each call and log it in microseconds.
3. Extend `Wire` and `Skeleton` so that `Capability` methods can take and return `String`
   arrays, and think about what would have to change for arbitrary objects.
4. Make the stub talk over a real `java.net.ServerSocket` in a second thread.

## Run

```
./run.sh 04
```

The output is Markdown; see [output.md](output.md) for the result of the last run.
