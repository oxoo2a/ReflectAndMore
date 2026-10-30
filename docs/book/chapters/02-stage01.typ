#import "../template.typ": *

#chapter(num: "Stage 01", title: "Run-time type information", tagline: [In which every object turns out to know exactly what it is, and `Class` turns out to be a thing you can hold in your hand.])

== Where we stand

Stage 00 could use `Candidate` but could not say anything _about_ it. Given a variable of type `Candidate`, Main could not find out whether the object was really a `Candidate` or a subclass; it could not compare two types; it could not take the string `"sa4e.reflect.Candidate"` and turn it into an object. All of that is compile-time knowledge, and at run time it was gone.

Except that it is not gone. This chapter is about the fact that the JVM keeps a complete description of every type, that this description is itself an object, and that you can ask it questions. Nothing is read or changed yet; that is stage 02. Stage 01 only looks.

== Every object knows its class

Here is the fact that makes everything else possible. Every object on the JVM heap starts with a header, and the header contains a pointer to the object's class. Not a type tag, not an integer, a pointer to a full description: name, superclass, interfaces, fields, methods, constant pool, and a reference to a `java.lang.Class` object that represents the class at the Java level. `getClass()` follows that pointer. It is one of the cheapest calls in the language, and it never lies.

Stage 01 adds a subclass so that there is something to lie about:

```java
public class Special extends Candidate implements Comparable<Special> {
    public Special(int x) { super(x); }

    @Override
    public int compareTo(Special other) {
        return Integer.compare(getX(), other.getX());
    }
}
```

and asks the obvious question:

```java
Candidate c = new Special(7);        // static type Candidate, dynamic type Special
r.kv("c.getClass()", c.getClass());
r.kv("c.getClass().getName()", c.getClass().getName());
r.kv("c instanceof Special", c instanceof Special);
```

#results(
  ("Candidate c = new Special(7)", "declared type Candidate"),
  ("c.getClass()", "class sa4e.reflect.Special"),
  ("c.getClass().getName()", "sa4e.reflect.Special"),
  ("c instanceof Special", "true"),
)

The variable `c` has the _static_ type `Candidate`: that is what the compiler knows and what it will let you call. The object has the _dynamic_ type `Special`: that is what the JVM knows. `instanceof` and virtual method dispatch have always used the dynamic type; `getClass()` simply hands it to you.

== Class objects are ordinary values

`c.getClass()` returns a `Class<?>`, and `Class` is a perfectly ordinary Java class. Its instances can be stored in variables, put in maps, passed to methods, compared with `==`. There is a literal syntax for them, `Candidate.class`, and there is one for every type in the language, including the ones that are not classes at all:

```java
Class<?>[] samples = {int.class, Integer.class, int[].class, String[][].class,
        Candidate.class, Special.class, Variant.class, Variant.A.class,
        Variant.Mode.class, Runnable.class, void.class};
```

#table(
  columns: (auto, auto, auto, auto),
  [getName()], [getSimpleName()], [getCanonicalName()], [kind],
  [#m("int")], [int], [int], [primitive],
  [#m("java.lang.Integer")], [Integer], [java.lang.Integer], [class],
  [#m("[I")], [int[]], [int[]], [array of int],
  [#m("[[Ljava.lang.String;")], [String[][]], [java.lang.String[][]], [array of String[]],
  [#m("sa4e.reflect.Candidate")], [Candidate], [sa4e.reflect.Candidate], [class],
  [#m("sa4e.reflect.Special")], [Special], [sa4e.reflect.Special], [class],
  [#m("sa4e.reflect.Variant")], [Variant], [sa4e.reflect.Variant], [sealed interface],
  [#m("sa4e.reflect.Variant$A")], [A], [sa4e.reflect.Variant.A], [record],
  [#m("sa4e.reflect.Variant$Mode")], [Mode], [sa4e.reflect.Variant.Mode], [enum],
  [#m("java.lang.Runnable")], [Runnable], [java.lang.Runnable], [interface],
  [#m("void")], [void], [void], [primitive],
)

A few things in this table surprise people the first time.

`int.class` exists and is not `Integer.class`. Primitives have Class objects so that reflection can describe a method like `f(int, double)` precisely; a parameter of type `int` and a parameter of type `Integer` are different things, and the JVM must know which one to box.

Arrays are classes, with names that look like line noise. `[I` is "array of int", `[[Ljava.lang.String;` is "array of array of String". These are the JVM's internal descriptors leaking through. `getSimpleName()` gives the human form, `getName()` gives the form that `Class.forName()` understands.

Nested classes use `$` in `getName()` and `.` in `getCanonicalName()`. `Variant$A` is the real name as far as the JVM and the class file are concerned; `Variant.A` is the Java-language spelling. Frameworks that take class names from configuration files must accept the `$` form, and the error messages of frameworks that do not are a small genre of their own.

Even `void` has a Class object, so that `getReturnType()` can return _something_ for a `void` method.

There is exactly one `Class` object per loaded class, which is why `==` works:

#results(
  ("Candidate.class == c.getClass()", "false"),
  ("Candidate.class == new Candidate().getClass()", "true"),
)

The first line is `false` because `c` is a `Special`. A `Class` object identifies a type exactly; it does not know about "is a kind of". For that there is `isAssignableFrom`, further down.

== From a string to a type

Now the door that everything in the second half of the book walks through:

```java
Class<?> byName = Class.forName("sa4e.reflect.Candidate");
Object instance = byName.getDeclaredConstructor().newInstance();
```

#results(
  ("Class.forName(\"sa4e.reflect.Candidate\")", "class sa4e.reflect.Candidate"),
  ("byName.getDeclaredConstructor().newInstance()", "Candidate{x=42, label='candidate#0'}"),
  ("Class.forName(\"Candidate\")", "ClassNotFoundException (the package is part of the name)"),
)

Read the first two lines slowly. The word `Candidate` does not appear as a type anywhere in them. A _string_ went in, an _object_ came out, and the string could have come from a properties file, a command-line argument, a database row or a network packet. This is how a JDBC driver manager finds `org.postgresql.Driver`, how a logging facade finds its back-end, how a plugin system finds plugins, and how a dependency-injection container finds everything. We are getting ahead of ourselves, and `getDeclaredConstructor().newInstance()` is really stage 02 material, but it was impossible to resist showing the door open.

The third line is the first error of the book and a common one: `Class.forName` wants the fully qualified name. There is no "current package" at run time; packages are part of the name, full stop.

#note[
  `Class.forName(name)` does three things: it _loads_ the class if it is not loaded yet, it _links_ it, and it _initializes_ it, which means running its static initializers. The third step is a side effect, and it is deliberate: for many years JDBC drivers registered themselves in a static initializer, and `Class.forName("org.postgresql.Driver")` was the idiom to trigger it. Stage 05 takes this apart.
]

== Walking the hierarchy

A `Class` object knows where it sits:

#results(
  ("superclass chain of Special", "Special -> Candidate -> Object"),
  ("Special.class.getInterfaces()", "[interface java.lang.Comparable]"),
  ("all interfaces of ArrayList (transitively)", "[List, SequencedCollection, Collection, Iterable, RandomAccess, Cloneable, Serializable]"),
  ("Object.class.getSuperclass()", "null"),
)

`getSuperclass()` returns one class or `null` at the top; `getInterfaces()` returns only the interfaces this class declares directly, so "all interfaces of ArrayList" needs a little recursion over superclasses and super-interfaces. The loop that produced the first line is three lines of code:

```java
for (Class<?> k = Special.class; k != null; k = k.getSuperclass()) {
    chain.append(k.getSimpleName()).append(k.getSuperclass() != null ? " -> " : "");
}
```

Every serializer walks exactly this loop to find the fields of superclasses, and every container walks it to find annotations on them.

== Type tests and casts, without the syntax

Everything `instanceof` and the cast operator do is also available as a method call on a `Class` object, which matters when the class is a variable rather than a name in the source:

#results(
  ("Candidate.class.isAssignableFrom(Special.class)", "true"),
  ("Special.class.isAssignableFrom(Candidate.class)", "false"),
  ("Special.class.isInstance(c)", "true"),
  ("Special.class.cast(c).getX()", "7"),
  ("Variant.A.class.cast(c)", "ClassCastException"),
)

`a.isAssignableFrom(b)` reads as "a variable of type `a` can hold a `b`". The direction trips everyone up at least once; the mnemonic is that it mirrors an assignment `a = b`. `isInstance` is `instanceof` with the type on the left, and `cast` is the cast operator, including the `ClassCastException` when it fails. The one new thing `cast` gives you is a _typed_ return value: `Special.class.cast(c)` is a `Special` as far as the compiler is concerned, so you can call `getX()` on it directly.

When stage 06 asks "which registered classes implement `Capability`?", the answer is one `isAssignableFrom` per registered class. That is the whole algorithm.

== The compiler uses RTTI too

Modern Java has pattern matching, and it is worth pausing to notice that it is built on the same foundation:

```java
public sealed interface Variant permits Variant.A, Variant.B {
    record A(int value, String tag) implements Variant {}
    final class B implements Variant { /* ... */ }
    enum Mode { ON, OFF, UNKNOWN }
}
```

```java
String text = switch (v) {                 // no default branch needed
    case Variant.A a -> "A with value " + a.value() + " and tag " + a.tag();
    case Variant.B b -> "B with weight " + b.weight();
};
```

#results(
  ("switch (v) for a A", "A with value 1 and tag one"),
  ("switch (v) for a B", "B with weight 2.5"),
)

The switch compiles to type tests against the object's class, the same test `isInstance` performs. And because `Variant` is _sealed_, the compiler knows that `A` and `B` are the only possibilities and does not demand a `default`. Sealed types are RTTI that the compiler can reason about; the next section shows that the run time can see it as well.

== Types that describe themselves

Sealed interfaces, records and enums all carry extra structure, and all of it is visible at run time:

#results(
  ("Variant.class.isSealed()", "true"),
  ("Variant.class.getPermittedSubclasses()", "[A, B]"),
  ("Variant.A.class.isRecord()", "true"),
  ("Variant.A.class.getRecordComponents()", "value: int, tag: String"),
  ("Variant.B.class.isRecord()", "false"),
  ("Variant.Mode.class.isEnum()", "true"),
  ("Variant.Mode.class.getEnumConstants()", "[ON, OFF, UNKNOWN]"),
)

`getRecordComponents()` deserves a highlight. A record declares its components once, in the header, and the JVM remembers them in order, with names and types. A serializer that meets a record does not have to guess which fields matter or which constructor to call: the components are the fields, the canonical constructor takes them in exactly this order, and the accessors have exactly these names. Records were designed, among other things, to make reflection boring, and stage 02 will make use of that.

== Generics: erased from objects, kept in declarations

Here is the one place where the "every object knows its class" story has a hole:

#results(
  ("new ArrayList<String>().getClass() == new ArrayList<Integer>().getClass()", "true"),
)

The two lists have the same class. Type arguments are erased when the compiler is done with them; at run time there is only `ArrayList`. This is the famous _type erasure_, and it is the reason you cannot write `new T()` or `list instanceof List<String>`.

But erasure applies to _objects_, not to _declarations_. A field declared as `List<String>`, a method returning `Map<String, List<Integer>>`, a class extending `TypeRef<List<String>>`: these declarations keep their full generic signature in the class file, and reflection can read it back:

```java
static class Holder {
    List<String> items = new ArrayList<>();
    Map<String, List<Integer>> index = Map.of();
}
```

#results(
  ("field items: getType()", "List"),
  ("field items: getGenericType()", "java.util.List<java.lang.String>"),
  ("field index: getType()", "Map"),
  ("field index: getGenericType()", "java.util.Map<java.lang.String, java.util.List<java.lang.Integer>>"),
)

`getType()` is the erased class; `getGenericType()` is the declaration, as a `java.lang.reflect.Type` that can be a `ParameterizedType` with actual type arguments. This is how Jackson knows that the field `items` should be filled with strings, not with `Object`s, when it reads JSON.

And then there is the trick that every Java developer should see once, because it looks like black magic and is not:

```java
public abstract class TypeRef<T> {
    private final Type type;

    protected TypeRef() {
        Type superclass = getClass().getGenericSuperclass();
        if (!(superclass instanceof ParameterizedType parameterized)) {
            throw new IllegalStateException("use: new TypeRef<SomeType>() {}");
        }
        this.type = parameterized.getActualTypeArguments()[0];
    }

    public Type type() { return type; }
}
```

```java
TypeRef<List<String>> ref = new TypeRef<>() {};
r.kv("new TypeRef<List<String>>() {}.type()", ref.type());
```

#results(
  ("new TypeRef<List<String>>() {}.type()", "java.util.List<java.lang.String>"),
)

The `{}` at the end is the whole trick. It creates an _anonymous subclass_ of `TypeRef<List<String>>`, and that subclass is a declaration, so its generic superclass survives erasure. The constructor reads it back. Jackson's `TypeReference`, Gson's `TypeToken` and Guice's `TypeLiteral` are this class, and now you know why you have to write those curly braces.

== Lambdas and anonymous classes have classes too

The last section is a teaser for stage 07:

#results(
  ("lambda.getClass().getName()", "sa4e.reflect.Main$$Lambda/0x0000018001046660"),
  ("lambda.getClass().isHidden()", "true"),
  ("anonymous.getClass().getName()", "sa4e.reflect.Main$2"),
  ("anonymous.getClass().isAnonymousClass()", "true"),
)

An anonymous class is compiled by `javac` into an ordinary class file called `Main$2.class`. A lambda is not: there is no class file for it anywhere. The class `Main$$Lambda/0x...` is generated by the JVM the first time the lambda expression runs, and it is _hidden_: it has no findable name, `Class.forName` cannot see it, and it disappears when it is no longer referenced. Stage 07 generates classes exactly like this, so remember the word "hidden".

#wild[
  - Every DI container starts with `isAssignableFrom` to find candidates for an interface, and with `Class.forName` to turn configuration into classes.
  - JDBC (`Class.forName("org.postgresql.Driver")`), JNDI, logging back-ends, JAX-RS runtimes and plugin systems all begin with a class name in a string.
  - Jackson's `TypeReference<List<Customer>>`, Gson's `TypeToken` and Guice's `TypeLiteral` are `TypeRef`.
  - Hibernate reads `getGenericType()` of every collection-typed field to know what an `@OneToMany` contains.
]

#bill[
  Almost nothing. `getClass()` is a pointer dereference, `isInstance` is the same check as `instanceof`, and the `Class` objects already exist because the JVM needs them anyway. The one expensive and side-effect-laden call is `Class.forName`, which may load and initialize a class; stage 05 is about exactly that.
]

#tryit[
  + Print the full inheritance chain of `java.util.LinkedHashMap` including all interfaces, transitively, without duplicates.
  + Write `boolean sameHierarchy(Object a, Object b)` that returns true when one object's class is a subclass of the other's, without using `instanceof`.
  + Make `TypeRef` work for nested arguments such as `Map<String, List<Integer>>` and print the inner types recursively. (Hint: `ParameterizedType` is itself a `Type`.)
]

#takeaway[
  - Every object knows its class; `getClass()` returns the dynamic type, the one the JVM uses for dispatch.
  - `Class` objects are values: one per loaded type, comparable with `==`, obtainable from a literal, from an object or from a string.
  - `isAssignableFrom`, `isInstance` and `cast` are `instanceof` and the cast operator for cases where the type is a variable.
  - Sealed types, records and enums describe their own structure, which makes them easy for frameworks.
  - Generics are erased from objects but kept in declarations; the super type token exploits exactly that.
]
