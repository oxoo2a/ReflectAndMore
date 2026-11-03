#import "../template.typ": *

#chapter(num: "Stage 02", title: "Reflection", tagline: [In which we read `Candidate` like a book, call what we are not supposed to call, and discover that the JDK has built itself a wall.])

== Where we stand

Stage 01 could ask a class _what_ it is. It could not ask what the class _contains_, and it could not do anything with the answer: no object creation with arguments, no method call by name, no access to a field unless the field's name was typed into the source. The `Inspector` that this chapter builds answers the first question for any class in the world, and the second half of the chapter does the rest: create, call, read, write, by name, at run time.

The package is `java.lang.reflect`, and its central idea is that every _member_ of a class is itself an object. A `Constructor`, a `Field`, a `Method`, a `Parameter`: each can be listed, inspected and used. The `Class` object from stage 01 is the index; these are the entries.

== Inspector: describing a class you have never seen

The lecture slides call this example "TalkAbout". It takes a `Class<?>` and produces an XML description of it, and it does so without instantiating the class, without importing it, and without knowing it at compile time:

```java
public final class Inspector {
    private final Class<?> target;

    public Inspector(Class<?> target) { this.target = target; }

    public String describe() {
        StringWriter text = new StringWriter();
        try {
            XMLStreamWriter xml = XMLOutputFactory.newDefaultFactory()
                                                  .createXMLStreamWriter(text);
            xml.writeStartDocument("UTF-8", "1.0");
            startElement(xml, "class");
            xml.writeAttribute("name", target.getName());
            xml.writeAttribute("modifiers", Modifier.toString(target.getModifiers()));
            xml.writeAttribute("superclass", target.getSuperclass().getName());

            // The reflection API makes no promise about the order of members, so sort.
            Constructor<?>[] constructors = target.getDeclaredConstructors();
            Arrays.sort(constructors,
                        Comparator.comparing(Constructor::toGenericString));
            for (Constructor<?> ctor : constructors) {
                startElement(xml, "constructor");
                xml.writeAttribute("modifiers", Modifier.toString(ctor.getModifiers()));
                writeParameters(xml, ctor);
                endElement(xml);
            }

            Field[] fields = target.getDeclaredFields();
            Arrays.sort(fields, Comparator.comparing(Field::getName));
            for (Field f : fields) {
                emptyElement(xml, "field");
                xml.writeAttribute("name", f.getName());
                xml.writeAttribute("type", f.getType().getName());
                xml.writeAttribute("modifiers", Modifier.toString(f.getModifiers()));
            }

            Method[] methods = target.getDeclaredMethods();
            Arrays.sort(methods, Comparator.comparing(Method::getName));
            for (Method m : methods) {
                if (m.isSynthetic()) continue;        // compiler-generated helpers
                startElement(xml, "method");
                xml.writeAttribute("name", m.getName());
                xml.writeAttribute("modifiers", Modifier.toString(m.getModifiers()));
                xml.writeAttribute("returns", m.getReturnType().getName());
                writeParameters(xml, m);
                endElement(xml);
            }
            endElement(xml);                          // </class>
            xml.writeEndDocument();
            xml.close();
        } catch (XMLStreamException e) {
            throw new IllegalStateException("cannot write XML", e);
        }
        return text.toString();
    }

    /** Constructors and methods share the type Executable: parameters handled once. */
    private static void writeParameters(XMLStreamWriter xml, Executable executable)
            throws XMLStreamException {
        for (Parameter p : executable.getParameters()) {
            emptyElement(xml, "parameter");
            xml.writeAttribute("name", p.getName());
            xml.writeAttribute("type", p.getType().getName());
        }
    }

    // Each element on its own line, indented by nesting depth: insignificant whitespace.
    private int depth;

    private void startElement(XMLStreamWriter xml, String name) throws XMLStreamException {
        newLine(xml);
        xml.writeStartElement(name);
        depth++;
    }

    private void endElement(XMLStreamWriter xml) throws XMLStreamException {
        depth--;
        newLine(xml);
        xml.writeEndElement();
    }

    private void newLine(XMLStreamWriter xml) throws XMLStreamException {
        xml.writeCharacters("\n" + "  ".repeat(depth));
    }
    // emptyElement: newLine, then writeEmptyElement
}
```
#src[stage02-reflection/src/main/java/sa4e/reflect/Inspector.java (abridged)]

Three families of calls do all the work: `getDeclaredConstructors()`, `getDeclaredFields()` and `getDeclaredMethods()`. Each returns an array of member objects, and each member object can tell its name, its modifiers as a bit mask that `Modifier.toString` turns into `private static final`, and its types. Constructors and methods share a superclass, `Executable`, so parameters are handled once for both.

The XML itself is not glued together from strings. The JDK ships a streaming XML writer, `javax.xml.stream.XMLStreamWriter` from the StAX API in module `java.xml`, and `Inspector` dictates the document to it element by element: open an element, add its attributes, write what is inside, close it. The writer escapes attribute values and text and remembers which elements are open, so the output is well-formed by construction and `Inspector` never has to think about quotes, angle brackets or closing tags. Whitespace between elements means nothing in XML; the small helpers at the end add a line break and two spaces per nesting level before each element, so that the result can be read by people as well as parsers. Why XML and not JSON? Because the JDK can write and parse XML and has no JSON API, and because XML is where the metadata of enterprise frameworks historically lived, as the next chapter will show; a JSON edition is one XSLT stylesheet away. Applied to `Candidate`, the result is:

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

Compare this with the `javap` listing at the end of stage 00. It is the same information, produced by a running program instead of a command-line tool. The private constructor, the private field, the private method: all there. Reflection does not respect visibility when _listing_; visibility only matters when you try to _use_ a member, and even then, as we will see, only up to a point.

=== Declared versus inherited

The word "Declared" in those method names is not decoration. `getDeclaredMethods()` returns every method _declared in this class_, of any visibility, and nothing inherited. `getMethods()` returns every _public_ method, including inherited ones, all the way up to `Object`:

#results(
  ("Candidate.class.getDeclaredMethods().length", "6 (all methods declared in Candidate, any visibility)"),
  ("Candidate.class.getMethods().length", "12 (public methods only, but including those inherited from Object)"),
  ("Special.class.getDeclaredMethods().length", "2 (compareTo plus a synthetic bridge method generated for Comparable<Special>)"),
)

Six declared methods in `Candidate`: `created`, `f`, `getX`, `reset`, `secret`, `toString`. Twelve public methods: `created`, `f`, `getX`, `toString`, plus `equals`, `hashCode`, `getClass`, `notify`, `notifyAll` and three overloads of `wait` from `Object`. Neither view is "the" list of methods; which one you want depends on what you are doing. A serializer wants declared fields of the class _and_ of its superclasses, so it walks the superclass chain from stage 01 and calls `getDeclaredFields()` on each.

The third line hides a small lesson. `Special` declares one method, `compareTo(Special)`, but the JVM sees two. Because `Comparable<T>` erases to `compareTo(Object)`, the compiler generates a _bridge_ method with that signature that casts and delegates. It is marked `synthetic`, and `Inspector` skips synthetic members for that reason. Expect them; every generic class has some.

=== Parameter names, if you ask nicely

The XML above shows `<parameter name="y" type="int"/>`. That is less obvious than it looks:

#results(
  ("parameter of f: y : int", "isNamePresent=true"),
  ("parameter of f: d : double", "isNamePresent=true"),
)

Parameter names are not in the class file by default. The JVM does not need them, so `javac` throws them away unless it is told to keep them with the flag `-parameters`. Without that flag, `Parameter.getName()` returns `arg0`, `arg1`, and `isNamePresent()` returns `false`. This project compiles with the flag because frameworks depend on it: Spring MVC maps a request parameter `?x=5` to a method parameter called `x` by name, and Jakarta REST and most JSON binders for constructors do the same. If you ever see `arg0` in an error message from such a framework, you now know which flag is missing.

== Creating objects by name

The second half of the chapter stops looking and starts touching. First, construction:

```java
Class<?> type = Class.forName("sa4e.reflect.Candidate");
Object viaPublic = type.getConstructor(int.class).newInstance(7);

Constructor<?> hidden = type.getDeclaredConstructor(String.class);
hidden.setAccessible(true);                       // private: this is the key
Object viaPrivate = hidden.newInstance("made by reflection");
```

#results(
  ("type.getConstructor(int.class).newInstance(7)", "Candidate{x=7, label='candidate#7'}"),
  ("private constructor, after setAccessible(true)", "Candidate{x=-1, label='made by reflection'}"),
)

`getConstructor(int.class)` selects a constructor by its parameter types, exactly as the compiler would, and `newInstance(7)` calls it with boxed arguments. `getConstructor` sees only public constructors; `getDeclaredConstructor` sees all of them. And then the line that the whole chapter has been building up to: `setAccessible(true)`.

`setAccessible(true)` asks the reflection API to skip the language-level access check for this one member. After it, a private constructor can be called, a private method invoked, a private field read and written. It is the single most consequential method in `java.lang.reflect`, and every framework in the book's "In the wild" boxes calls it. It is also the method that Java 16 decided to say no to, in some circumstances, and we will get to that.

== Calling methods by name

```java
Candidate c = new Candidate(1);
Candidate.class.getMethod("f", int.class, double.class).invoke(c, 3, -1.0);

Method secret = Candidate.class.getDeclaredMethod("secret");
secret.setAccessible(true);
Object s = secret.invoke(c);

Method created = Candidate.class.getMethod("created");
Object n = created.invoke(null);                  // static: no target object
```

#results(
  ("getMethod(\"f\", int.class, double.class).invoke(c, 3, -1.0)", "Candidate{x=3, label='candidate#1'}"),
  ("private secret() after setAccessible(true)", "the secret of candidate#1"),
  ("static created(), invoked with target null", "3"),
  ("Integer.parseInt(\"forty-two\") via reflection", "InvocationTargetException wrapping java.lang.NumberFormatException: For input string: \"forty-two\""),
  ("secret.invoke(\"not a Candidate\")", "IllegalArgumentException: object of type java.lang.String is not an instance of sa4e.reflect.Candidate"),
)

`Method.invoke(target, args...)` is the universal call. The target is the object to call the method on, or `null` for a static method. Arguments travel as `Object`, so `3` is boxed to an `Integer` on the way in and unboxed to an `int` by the JVM on the way out; the return value comes back boxed as well. Everything the compiler would have checked at compile time is now checked at run time, and the last two lines show what that looks like.

The fourth line is the one that bites everyone once. When the _called method_ throws, `invoke` does not rethrow that exception. It wraps it in an `InvocationTargetException` whose `getCause()` is the real one. The reason is sound: `invoke` must distinguish "I could not perform the call" (wrong argument count, no access) from "the call ran and threw", and Java's checked-exception rules leave no other way. The consequence is that every piece of reflective code contains a `catch (InvocationTargetException e) { throw e.getCause(); }` somewhere, and so will ours in stage 04.

== Reading and writing fields, even final ones

```java
Field x = Candidate.class.getDeclaredField("x");
Field label = Candidate.class.getDeclaredField("label");
x.setAccessible(true);
label.setAccessible(true);

label.set(c, "changed although final");     // allowed on ordinary instance fields
Field counter = Candidate.class.getDeclaredField("created");
counter.setAccessible(true);
counter.setInt(null, 1000);                  // static field: target is null
```

#results(
  ("x.getInt(c)", "3"),
  ("label.get(c)", "candidate#1"),
  ("label.set(c, \"changed although final\")", "Candidate{x=3, label='changed although final'}"),
  ("counter.setInt(null, 1000); Candidate.created()", "1000"),
  ("value.setInt(record, 2) on a record", "IllegalAccessException: Can not set final int field sa4e.reflect.Variant$A.value to (int)2"),
)

The third line should make you slightly uncomfortable. `label` is declared `private final`, and we changed it. For instance fields of ordinary classes, `setAccessible(true)` lifts the `final` as well as the `private`. This is not an oversight; serialization frameworks need it. When Jackson deserializes JSON into an object with final fields and no suitable constructor, this is how it does it, and `java.io.ObjectInputStream` has done the same since 1997.

The fifth line is where the JVM draws a line of its own. Fields of a _record_ cannot be set this way, not even with `setAccessible(true)`; neither can `static final` fields or fields of hidden classes. Records promised immutability as part of their contract, and the JVM keeps that promise against reflection. A serializer that meets a record must go through the canonical constructor, which is exactly what `getRecordComponents()` from stage 01 makes easy.

== The wall

Everything so far worked on our own classes. Now try it on the JDK:

```java
Field stringValue = String.class.getDeclaredField("value");
stringValue.setAccessible(true);             // throws
```

#results(
  ("String.class.getDeclaredField(\"value\")", "private final byte[] java.lang.String.value (reading metadata always works)"),
  ("stringValue.setAccessible(true)", "InaccessibleObjectException: Unable to make field private final byte[] java.lang.String.value accessible: module java.base does not \"opens java.lang\" to unnamed module @5b6f7412"),
)

Listing the field works, as it always does; metadata is never hidden. But `setAccessible(true)` throws an `InaccessibleObjectException`, and the message tells the whole story: the module `java.base` does not _open_ the package `java.lang` to our code.

This is _strong encapsulation_, introduced with the module system in Java 9 and enforced by default since Java 16. The JDK's own packages are closed to deep reflection unless a module explicitly opens them, and `java.base` does not. Before Java 16, the line above would have worked, and a dozen popular libraries used it to mutate strings, poke at `Unsafe` or rewrite class loaders. When Java 16 closed the door, those libraries broke, their authors complained, and the JDK team held firm, with one concession: the JVM flag

```sh
java --add-opens java.base/java.lang=ALL-UNNAMED ...
```

opens a package at launch time for code that genuinely needs it. If you have ever wondered why a Gradle build or an application server starts with a dozen `--add-opens` flags, this is why.

#note[
  Your own code can build the same wall. A `module-info.java` that does not `opens` a package makes that package's private members inaccessible to reflection from outside, even with `setAccessible(true)`. Frameworks that need deep reflection ask you to `opens your.package to spring.core;`. Without a module descriptor, as in this project, your classes live in the "unnamed module", which is open to everyone, which is why every example in this book just works.
]

== Arrays

Arrays are classes, so of course there is reflection for them:

```java
Object array = Array.newInstance(Candidate.class, 2);   // a Candidate[2]
Array.set(array, 0, new Candidate(5));
Array.set(array, 1, viaPrivate);
```

#results(
  ("Array.newInstance(Candidate.class, 2)", "Candidate[] of length 2"),
  ("Array.get(array, 1)", "Candidate{x=-1, label='made by reflection'}"),
)

`java.lang.reflect.Array` creates and accesses arrays whose component type is a variable. It exists because `new T[n]` is impossible with erased generics, and because a deserializer that reads a JSON array has only a `Class<?>` to say what kind of array to build.

== Invoker: a convenience layer

The raw API asks for exact parameter types: `getMethod("f", int.class, double.class)`. That is precise but tedious, and it is not what a scripting engine or a test framework wants. They have a name and some argument values, and they want the member that fits. `Invoker` is forty lines that do that:

```java
public static Object call(Object target, String name, Object... args)
        throws ReflectiveOperationException {
    boolean isStatic = target instanceof Class<?>;
    Class<?> type = isStatic ? (Class<?>) target : target.getClass();
    for (Class<?> k = type; k != null; k = k.getSuperclass()) {
        for (Method m : k.getDeclaredMethods()) {
            if (m.getName().equals(name) && matches(m.getParameterTypes(), args)) {
                m.setAccessible(true);
                return m.invoke(isStatic ? null : target, args);
            }
        }
    }
    throw new NoSuchMethodException(type.getName() + "." + name);
}

/** True if every argument fits the corresponding parameter (boxing included). */
private static boolean matches(Class<?>[] parameterTypes, Object[] args) {
    if (parameterTypes.length != args.length) return false;
    for (int i = 0; i < args.length; i++) {
        if (args[i] == null) {
            if (parameterTypes[i].isPrimitive()) return false;   // null is no int
            continue;
        }
        if (!wrap(parameterTypes[i]).isInstance(args[i])) return false;
    }
    return true;
}

/** int.class -> Integer.class etc.; non-primitive types are returned unchanged. */
private static Class<?> wrap(Class<?> type) {
    return type.isPrimitive() ? MethodType.methodType(type).wrap().returnType() : type;
}
```
#src[stage02-reflection/src/main/java/sa4e/reflect/Invoker.java (abridged)]

Every piece of stage 01 is in there: the superclass walk, `isInstance`, `isPrimitive`. The `wrap` helper is a small trick worth stealing: `MethodType` from `java.lang.invoke` knows how to map `int.class` to `Integer.class`, so nobody has to write the eight-entry table by hand.

#results(
  ("Invoker.newInstance(\"sa4e.reflect.Candidate\", 9)", "Candidate{x=9, label='candidate#9'}"),
  ("Invoker.call(made, \"secret\")", "the secret of candidate#9"),
  ("Invoker.call(made, \"f\", 4, 1.5)", "Candidate{x=-4, label='candidate#9'}"),
  ("Invoker.call(Candidate.class, \"created\")", "1002"),
  ("Invoker.set(made, \"x\", 77); Invoker.get(made, \"x\")", "77"),
  ("Invoker.call(new Special(3), \"secret\")", "the secret of candidate#3 (inherited private method)"),
)

Notice the last line: `secret()` is private to `Candidate`, and `Invoker` found and called it on a `Special`. The compiler would never have allowed that. Notice also what we paid for the convenience: method names are now strings. The compiler cannot check them, and when someone renames `secret` to `hint`, the IDE's refactoring will not follow the string. Every framework that identifies members by name lives with this, which is one reason the next stage introduces annotations.

== What does it cost?

The last section of stage 02 measures. Twenty million calls of `getX()` on four different objects, after three warm-up rounds so that the JIT compiler has done its work:

```java
Method m = Candidate.class.getMethod("getX");
MethodHandle mh = MethodHandles.lookup()
        .findVirtual(Candidate.class, "getX", MethodType.methodType(int.class));

for (int i = 0; i < n; i++) sum += targets[i & 3].getX();              // direct
for (int i = 0; i < n; i++) sum += (int) m.invoke(targets[i & 3]);     // reflection
for (int i = 0; i < n; i++) sum += (int) mh.invokeExact(targets[i & 3]); // method handle
```

#table(
  columns: (auto, auto),
  align: (left, right),
  [Call style], [ns per call],
  [direct call], [0.35],
  [`Method.invoke`], [6.27],
  [`MethodHandle.invokeExact`], [2.37],
)

These numbers are from one laptop and one run, with no benchmark harness, so treat them as a shape, not a measurement. The shape is reliable: a reflective call costs an order of magnitude more than a direct call, because arguments are boxed into an `Object[]`, access is checked, and the JIT cannot inline through `invoke`. The third row introduces `java.lang.invoke.MethodHandle`, a lower-level mechanism from Java 7 that is typed, does no boxing with `invokeExact`, and sits much closer to a direct call. Since Java 18, `Method.invoke` is itself implemented on top of method handles (JEP 416), which is why the gap is smaller than it used to be.

The practical rule is simple. Frameworks do reflection _once_, at startup, to find out what to do, and then do it millions of times through something cheaper: a cached `Method`, a `MethodHandle`, a generated class (stage 07). Reflection in a hot loop is a bug.

#wild[
  - Jackson and Gson read and write private fields exactly as in the fields section, final ones included.
  - JUnit finds and invokes test methods as in the methods section; stage 03 adds the annotations that tell it which ones.
  - Spring and Jakarta CDI call constructors by reflection as in the construction section, with arguments they resolved themselves (stage 06).
  - Mockito, Hibernate and most serialization frameworks needed `--add-opens` flags or rewrites when Java 16 enforced the wall.
]

#bill[
  - Member names are strings: no compile-time check, no refactoring support, errors at run time.
  - A reflective call is several times slower than a direct one; cache members, use method handles, never reflect in a loop.
  - Reflection defeats encapsulation. The JDK protects itself since Java 16; your own modules can do the same.
  - GraalVM native image compiles with a closed world and cannot see the strings; everything accessed reflectively must be listed in `reachability-metadata.json`, or it is simply not there at run time.
]

#tryit[
  + Let `Inspector` emit JSON instead of XML, and add the inherited public methods (`getMethods()`) as a separate section.
  + `Invoker.call(made, "f", 4, 1)` fails, because `1` is an `Integer` and the parameter is `double`. Add widening conversions.
  + Run stage 02 with `./run.sh 02 --add-opens java.base/java.lang=ALL-UNNAMED` and change the content of a `String` in place. Then explain why string literals elsewhere in the program may change too. (Hint: the string pool.)
  + Replace `Method.invoke` in the benchmark by a lambda created with `LambdaMetafactory` and compare again.
]

#takeaway[
  - Every member of a class is an object: `Constructor`, `Field`, `Method`, `Parameter`. Listing them ignores visibility; using them respects it, until `setAccessible(true)`.
  - `invoke` wraps exceptions from the called method in `InvocationTargetException`; always unwrap.
  - Final instance fields of ordinary classes can be changed; record fields, static finals and hidden classes cannot.
  - The JDK is closed to deep reflection since Java 16; `--add-opens` is the escape hatch.
  - Reflect once, cache, and call through something cheaper.
]
