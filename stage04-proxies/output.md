# Stage 04: dynamic proxies

_Java 25+37-LTS-jvmci-b01, Java HotSpot(TM) 64-Bit Server VM (Oracle Corporation), /Users/sturm/.sdkman/candidates/java/25-graal_

## 1. The pain: a decorator per interface and per concern

| Expression                                                        | Result               |
|-------------------------------------------------------------------|----------------------|
| `new LoggingCapability(new Candidate(7), log).f(3, -1.0); getX()` | 3                    |
| `log`                                                             | [f(3, -1.0), getX()] |

> ℹ LoggingCapability works, but it knows Capability. Logging for a second interface means a second class, and a second concern (transactions, security, caching) means a class for every interface again.

## 2. The same with a dynamic proxy: one handler for all interfaces

| Expression                             | Result                                                                                                                 |
|----------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| `proxy.f(3, -1.0); proxy.getX()`       | 3                                                                                                                      |
| `proxy.toString()`                     | Candidate{x=3, label='candidate#7'}                                                                                    |
| `log`                                  | [→ f(3, -1.0), ← f(3, -1.0), → getX(), ← getX() = 3, → toString(), ← toString() = Candidate{x=3, label='candidate#7'}] |
| `proxy.getClass().getName()`           | jdk.proxy1.$Proxy0                                                                                                     |
| `Proxy.isProxyClass(proxy.getClass())` | true                                                                                                                   |
| `proxy.getClass().getInterfaces()`     | [interface sa4e.reflect.Capability]                                                                                    |
| `proxy instanceof Capability`          | true                                                                                                                   |
| `proxy instanceof Candidate`           | false                                                                                                                  |

> ℹ Proxy.newProxyInstance generates a class at run time that implements the interface. Each method of that class does nothing but call handler.invoke(this, method, args). Even toString() goes through the handler, which is why it appears in the log.

## 3. What the generated class looks like

```xml
<?xml version="1.0" encoding="UTF-8"?>
<class name="jdk.proxy1.$Proxy0" modifiers="public final" superclass="java.lang.reflect.Proxy">
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
  <method name="proxyClassLookup" modifiers="private static" returns="java.lang.invoke.MethodHandles$Lookup">
    <parameter name="arg0" type="java.lang.invoke.MethodHandles$Lookup"/>
  </method>
  <method name="toString" modifiers="public final" returns="java.lang.String">
  </method>
</class>
```

> ℹ The Inspector from stage 02 works on the generated class as on any other: it is final, extends java.lang.reflect.Proxy (which holds the handler in field h), and caches the Method objects it passes to the handler in static fields m0, m1, ...

## 4. A chain of handlers: logging, transactions, validation

| Expression                          | Result                                                                                                                                            |
|-------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| `chained.f(5, 1.0); chained.getX()` | -5                                                                                                                                                |
| `chained.f(1000, 1.0)`              | IllegalArgumentException: y = 1000 is outside [-10, 10]                                                                                           |
| `real.getX() afterwards`            | -5                                                                                                                                                |
| `log`                               | [→ f(5, 1.0), ← f(5, 1.0), → getX(), ← getX() = -5, → f(1000, 1.0), ✗ f(1000, 1.0) threw IllegalArgumentException: y = 1000 is outside [-10, 10]] |
| `tx.entries()`                      | [begin tx1 for f(5, 1.0), commit tx1, begin tx2 for f(1000, 1.0), rollback tx2 because of IllegalArgumentException]                               |

> ℹ Each proxy forwards to the next; the real object is reached last and knows nothing about any of it. f is @Transactional and getX is not, so only f produces begin/commit. The invalid call is rejected by the validating handler, the transaction is rolled back, and the logging handler records the exception. This is the EJB container and Spring AOP in three classes.

## 5. Where do the annotations live?

| Expression                                                                      | Result    |
|---------------------------------------------------------------------------------|-----------|
| `Capability.class.getMethod("f", ...).isAnnotationPresent(Transactional.class)` | false     |
| `Candidate.class.getMethod("f", ...).isAnnotationPresent(Transactional.class)`  | true      |
| `Proxies.unwrap(chained) == real`                                               | true      |
| `Proxies.unwrap(chained).getClass()`                                            | Candidate |

> ℹ The Method handed to a handler belongs to the interface, where nothing is annotated. The handlers therefore look up the implementing method on the real object's class. In a chain the next object is itself a proxy, so Proxies.unwrap follows the handlers' targets down to Candidate first. Spring does the same (AopUtils.getTargetClass) and documents that annotations on interfaces are not always honoured.

## 6. A virtual proxy: the real object is created on first use

| Expression                                            | Result |
|-------------------------------------------------------|--------|
| `after creating the lazy proxy: lazy.isInitialized()` | false  |
| `Candidate.created() unchanged`                       | true   |
| `lazyProxy.getX()`                                    | 9      |
| `now lazy.isInitialized()`                            | true   |

> ℹ JPA entities with lazy associations are proxies like this: the database is queried the moment the first getter is called, which is also why LazyInitializationException exists.

## 7. A remote stub: the handler sends the call somewhere else

| Expression                     | Result                                                                                                                                                                                                                      |
|--------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `stub.f(2, -1.0); stub.getX()` | 2                                                                                                                                                                                                                           |
| `stub.f(1000, 1.0)`            | remote: IllegalArgumentException: y = 1000 is outside [-10, 10]                                                                                                                                                             |
| `stub.toString()`              | RemoteStub[Capability]                                                                                                                                                                                                      |
| `wire`                         | [request: f\|int,double\|int:2\|double:-1.0, reply:   ok\|void, request: getX\|, reply:   ok\|int:2, request: f\|int,double\|int:1000\|double:1.0, reply:   error\|IllegalArgumentException: y = 1000 is outside [-10, 10]] |
| `server-side log`              | [→ f(2, -1.0), ← f(2, -1.0), → getX(), ← getX() = 2, → f(1000, 1.0), ✗ f(1000, 1.0) threw IllegalArgumentException: y = 1000 is outside [-10, 10]]                                                                          |

> ℹ The stub marshals the call into a string, the skeleton unmarshals it, finds the method by name and parameter types and invokes it reflectively. Replace the Function<String,String> with a socket or HTTP and this is RMI, SOAP or a REST client. The server side reuses the interceptor chain from section 4: that is the EJB container picture, stub, skeleton, container services, bean.

## 8. Pitfalls

| Expression                                         | Result                                                                                        |
|----------------------------------------------------|-----------------------------------------------------------------------------------------------|
| `handler throws IOException, getX() declares none` | UndeclaredThrowableException wrapping java.io.IOException: checked exception from the handler |
| `Proxies.wrap(Candidate.class, ...)`               | IllegalArgumentException: sa4e.reflect.Candidate is not an interface                          |

- Only interfaces: a proxy cannot stand in for a class. Frameworks generate subclasses for that (stage 07).
- Self-invocation: if Candidate.f called this.getX(), the call would bypass every handler. Spring's most frequently asked @Transactional question is exactly this.
- Identity: proxy != real, so equals and hashCode must be thought through.
- Checked exceptions not declared by the interface method are wrapped in UndeclaredThrowableException.
