# Stage 02: reflection

_Java 25+37-LTS-jvmci-b01, Java HotSpot(TM) 64-Bit Server VM (Oracle Corporation), /Users/sturm/.sdkman/candidates/java/25-graal_

## 1. Inspector: describing a class without knowing it

```xml
<?xml version="1.0" encoding="UTF-8"?>
<class name="sa4e.reflect.Candidate" modifiers="public" superclass="java.lang.Object">
  <constructor modifiers="private">
    <parameter name="label" type="java.lang.String"/>
  </constructor>
  <constructor modifiers="public">
  </constructor>
  <constructor modifiers="public">
    <parameter name="x" type="int"/>
  </constructor>
  <field name="created" type="int" modifiers="private static"/>
  <field name="label" type="java.lang.String" modifiers="private final"/>
  <field name="x" type="int" modifiers="private"/>
  <method name="created" modifiers="public static" returns="int">
  </method>
  <method name="f" modifiers="public" returns="void">
    <parameter name="y" type="int"/>
    <parameter name="d" type="double"/>
  </method>
  <method name="getX" modifiers="public" returns="int">
  </method>
  <method name="reset" modifiers="protected" returns="void">
  </method>
  <method name="secret" modifiers="private" returns="java.lang.String">
  </method>
  <method name="toString" modifiers="public" returns="java.lang.String">
  </method>
</class>
```

| Expression                                    | Result                                                                         |
|-----------------------------------------------|--------------------------------------------------------------------------------|
| `Candidate.class.getDeclaredMethods().length` | 6 (all methods declared in Candidate, any visibility)                          |
| `Candidate.class.getMethods().length`         | 12 (public methods only, but including those inherited from Object)            |
| `Special.class.getDeclaredMethods().length`   | 2 (compareTo plus a synthetic bridge method generated for Comparable<Special>) |

> ℹ The same Inspector works for any class, including the JDK's: try new Inspector(java.util.HashMap.class).

## 2. Parameter names survive only if the compiler is told to keep them

| Expression                   | Result             |
|------------------------------|--------------------|
| `parameter of f: y : int`    | isNamePresent=true |
| `parameter of f: d : double` | isNamePresent=true |

> ℹ This project compiles with -parameters. Without it the names are arg0, arg1 and frameworks such as Spring MVC could not map request parameters to method parameters by name.

## 3. Creating objects by name

| Expression                                       | Result                                      |
|--------------------------------------------------|---------------------------------------------|
| `type.getConstructor(int.class).newInstance(7)`  | Candidate{x=7, label='candidate#7'}         |
| `private constructor, after setAccessible(true)` | Candidate{x=-1, label='made by reflection'} |

> ℹ getConstructor finds only public constructors, getDeclaredConstructor finds all of them.

## 4. Calling methods by name

| Expression                                                   | Result                                                                                                 |
|--------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| `getMethod("f", int.class, double.class).invoke(c, 3, -1.0)` | Candidate{x=3, label='candidate#1'}                                                                    |
| `private secret() after setAccessible(true)`                 | the secret of candidate#1                                                                              |
| `static created(), invoked with target null`                 | 3                                                                                                      |
| `Integer.parseInt("forty-two") via reflection`               | InvocationTargetException wrapping java.lang.NumberFormatException: For input string: "forty-two"      |
| `secret.invoke("not a Candidate")`                           | IllegalArgumentException: object of type java.lang.String is not an instance of sa4e.reflect.Candidate |

> ℹ Arguments and return values are passed as Object; primitives are boxed and unboxed automatically.

## 5. Reading and writing fields, even private and final ones

| Expression                                        | Result                                                                                     |
|---------------------------------------------------|--------------------------------------------------------------------------------------------|
| `x.getInt(c)`                                     | 3                                                                                          |
| `label.get(c)`                                    | candidate#1                                                                                |
| `label.set(c, "changed although final")`          | Candidate{x=3, label='changed although final'}                                             |
| `counter.setInt(null, 1000); Candidate.created()` | 1000                                                                                       |
| `value.setInt(record, 2) on a record`             | IllegalAccessException: Can not set final int field sa4e.reflect.Variant$A.value to (int)2 |

> ℹ Records, hidden classes and static final fields are off limits even with setAccessible(true). Final instance fields of normal classes can be changed, which serialization frameworks rely on.

## 6. The wall: strong encapsulation of the JDK (since Java 9, enforced since 16)

| Expression                               | Result                                                                                                                                                                            |
|------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `String.class.getDeclaredField("value")` | private final byte[] java.lang.String.value (reading metadata always works)                                                                                                       |
| `stringValue.setAccessible(true)`        | InaccessibleObjectException: Unable to make field private final byte[] java.lang.String.value accessible: module java.base does not "opens java.lang" to unnamed module @5b6f7412 |

> ℹ java.base does not 'open' java.lang to us. Start the JVM with --add-opens java.base/java.lang=ALL-UNNAMED to allow it. Many frameworks needed exactly such flags when Java 16 closed the door.

## 7. Arrays through reflection

| Expression                              | Result                                      |
|-----------------------------------------|---------------------------------------------|
| `Array.newInstance(Candidate.class, 2)` | Candidate[] of length 2                     |
| `Array.get(array, 1)`                   | Candidate{x=-1, label='made by reflection'} |

## 8. Invoker: a convenience layer that picks the member by argument types

| Expression                                           | Result                                               |
|------------------------------------------------------|------------------------------------------------------|
| `Invoker.newInstance("sa4e.reflect.Candidate", 9)`   | Candidate{x=9, label='candidate#9'}                  |
| `Invoker.call(made, "secret")`                       | the secret of candidate#9                            |
| `Invoker.call(made, "f", 4, 1.5)`                    | Candidate{x=-4, label='candidate#9'}                 |
| `Invoker.call(Candidate.class, "created")`           | 1002                                                 |
| `Invoker.set(made, "x", 77); Invoker.get(made, "x")` | 77                                                   |
| `Invoker.call(new Special(3), "secret")`             | the secret of candidate#3 (inherited private method) |

> ℹ Member names as strings: no compile-time check, no help from the IDE when renaming. This is the price.

## 9. What does it cost? direct call vs. Method.invoke vs. MethodHandle

20,000,000 calls each, checksum 450000000.

| Call style               | ns per call |
|--------------------------|-------------|
| direct call              | 0.35        |
| Method.invoke            | 6.27        |
| MethodHandle.invokeExact | 2.37        |

> ℹ Numbers are indicative only (no proper benchmark harness). Since Java 18 Method.invoke is itself built on method handles (JEP 416); after warm-up the JIT removes most of the overhead for both.
