#import "../template.typ": *

#chapter(num: "Stage 03", title: "Annotations", tagline: [In which `Candidate` finally gets to talk back, and we write two frameworks before lunch.])

== Where we stand

Reflection, as of stage 02, is a one-way conversation. A framework can read everything about a class, but the class cannot say anything to the framework. Which field must never be null? Which method is a test? Which parameter has a valid range? Which constructor should a container use? In stage 02 such knowledge would have to live in the framework's code, in naming conventions (`testSomething`, `setSomething`) or in XML files kept somewhere else, going stale somewhere else.

Annotations are the answer: structured metadata, written _next to_ the thing it describes, checked by the compiler, and, with the right retention, readable through reflection. The first half of this chapter is about the mechanism. The second half builds two small frameworks on it, a validator and a test runner, and in doing so introduces the idea that will carry the rest of the book: inversion of control.

== Defining an annotation and reading it back

An annotation type is declared with `@interface`, and it is decorated with two meta-annotations that answer two questions: _where may it be written_ and _how long does it live_:

```java
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.CONSTRUCTOR, ElementType.FIELD,
         ElementType.METHOD, ElementType.PARAMETER})
public @interface Comment {
    String value() default "";
}
```
#src[stage03-annotations/src/main/java/sa4e/reflect/Comment.java]

`@Target` lists the kinds of elements that may carry the annotation; the compiler rejects `@Comment` on a local variable because `LOCAL_VARIABLE` is not in the list. `@Retention(RUNTIME)` says the annotation survives into the class file _and_ is visible to reflection, which is what we want here. The body declares _members_ as parameterless methods; `value()` is special in that `@Comment("text")` is shorthand for `@Comment(value = "text")`.

`Candidate` now wears a few of these:

```java
@Comment("the class under investigation")
@Marker
public class Candidate {

    @Range(min = -100, max = 100)
    private int x;

    @NotNull
    private final String label;

    @Comment("reads x")
    public int getX() { return x; }

    public void f(@Range(min = -10, max = 10) int y, double d) { /* unchanged */ }
    // ...
}
```

Nothing about `Candidate`'s behaviour changed. Annotations are inert: they are claims, and nothing happens unless someone reads them. Reading is one method, `getAnnotation`, available on everything that can be annotated:

#results(
  ("Candidate.class.getAnnotation(Comment.class).value()", "the class under investigation"),
  ("getX.getAnnotation(Comment.class).value()", "reads x"),
  ("Candidate.class.getMethod(\"f\", ...).isAnnotationPresent(Comment.class)", "false"),
  ("Candidate.class.getMethod(\"reset\")", "NoSuchMethodException (getMethod sees public methods only; use getDeclaredMethod)"),
  ("parameter y of f: getAnnotation(Range.class)", "min=-10, max=10"),
)

`Class`, `Constructor`, `Field`, `Method` and `Parameter` all implement `AnnotatedElement`, so the same `getAnnotation(Type.class)` works everywhere and returns `null` when the annotation is absent. The return type is the annotation type itself, so `.value()` is a normal, type-checked method call. Compare that with the stringly-typed `Invoker` of stage 02: annotations give the framework a vocabulary the compiler understands.

== Meta-annotations: annotations all the way down

`@Retention` and `@Target` are themselves annotations, on the annotation type, and they can be read like any other:

#results(
  ("Comment.class.isAnnotation()", "true"),
  ("Comment.class.getAnnotation(Retention.class).value()", "RUNTIME"),
  ("Comment.class.getAnnotation(Target.class).value()", "[TYPE, CONSTRUCTOR, FIELD, METHOD, PARAMETER]"),
  ("Comment.class.getDeclaredMethods()", "[public abstract java.lang.String sa4e.reflect.Comment.value()]"),
)

The last line is the one to remember: an annotation type is an _interface_, and its members are abstract methods. That has a consequence the next section exploits.

== Inspector lists annotations without knowing any

Because members are methods, a tool can read an annotation it has never heard of. Stage 03's `Inspector` gets one new helper:

```java
private void writeAnnotations(XMLStreamWriter xml, AnnotatedElement element)
        throws XMLStreamException {
    for (Annotation a : element.getAnnotations()) {
        Class<? extends Annotation> type = a.annotationType();
        Method[] members = type.getDeclaredMethods();
        Arrays.sort(members, Comparator.comparing(Method::getName));
        if (members.length == 0) {
            emptyElement(xml, "annotation");
            xml.writeAttribute("type", type.getName());
            continue;
        }
        startElement(xml, "annotation");
        xml.writeAttribute("type", type.getName());
        for (Method member : members) {
            newLine(xml);
            xml.writeStartElement("member");
            xml.writeAttribute("name", member.getName());
            xml.writeCharacters(String.valueOf(member.invoke(a)));  // read reflectively
            xml.writeEndElement();
        }
        endElement(xml);
    }
}
```

`Inspector` imports neither `Comment` nor `Range` nor `NotNull`. It asks the element for its annotations, asks each annotation for its type, asks the type for its methods, and _invokes_ those methods on the annotation instance with the `Method.invoke` of stage 02. The member's value goes out as text, and the StAX writer escapes it, whatever a comment string may contain. The output for `Candidate` now contains, for example:

```xml
  <field name="x" type="int" modifiers="private">
    <annotation type="sa4e.reflect.Range">
      <member name="max">100</member>
      <member name="min">-100</member>
    </annotation>
  </field>
  <method name="f" modifiers="public" returns="void">
    <parameter name="y" type="int">
      <annotation type="sa4e.reflect.Range">
        <member name="max">10</member>
        <member name="min">-10</member>
      </annotation>
    </parameter>
    <parameter name="d" type="double"/>
  </method>
```

This is also how an IDE, a documentation generator or a generic configuration dumper shows you annotations from libraries it has never seen.

== Retention: who can see the annotation?

`RetentionPolicy` has three values, and most people have only ever consciously used one. Stage 03 defines three annotations that differ in nothing else, puts all three on a probe class, and asks who can see them:

```java
@Retention(RetentionPolicy.SOURCE)  public @interface SourceOnly {}
@Retention(RetentionPolicy.CLASS)   public @interface ClassOnly {}     // the default
@Retention(RetentionPolicy.RUNTIME) public @interface RuntimeOnly {}

@SourceOnly @ClassOnly @RuntimeOnly
public static final class Probe {}
```

#results(
  ("Retentions.Probe.class.getAnnotations()", "[@sa4e.reflect.Retentions.RuntimeOnly()]"),
  ("class file attribute RuntimeVisibleAnnotations", "[Retentions$RuntimeOnly]"),
  ("class file attribute RuntimeInvisibleAnnotations", "[Retentions$ClassOnly]"),
)

Reflection sees only `RuntimeOnly`. To find out what happened to the other two we do not take anybody's word for it; we read the bytes of `Probe.class` with the ClassFile API, which Java 24 added to the JDK and which stage 07 uses in earnest:

```java
byte[] bytes = Retentions.Probe.class
        .getResourceAsStream("Retentions$Probe.class").readAllBytes();
ClassModel model = ClassFile.of().parse(bytes);
List<String> invisible = model.findAttribute(Attributes.runtimeInvisibleAnnotations())
        .map(a -> a.annotations().stream().map(x -> x.classSymbol().displayName()).toList())
        .orElse(List.of());
```

`ClassOnly` is in the class file, in an attribute literally called `RuntimeInvisibleAnnotations`. `SourceOnly` is nowhere: `javac` saw it, could have acted on it, and threw it away. So:

- `SOURCE` is for the compiler and for annotation processors: `@Override`, `@SuppressWarnings`, Lombok's `@Getter`.
- `CLASS`, the _default_ when `@Retention` is omitted, is for tools that read class files without running them: bytecode analysers, obfuscators, some build-time instrumentation. If you forget `@Retention` on your own annotation and then wonder why `getAnnotation` returns `null`, this is why.
- `RUNTIME` is for frameworks. Everything in this book is `RUNTIME`.

== Repeatable and inherited

Two refinements that frameworks use and that surprise people when they first meet them.

```java
@Repeatable(Tag.List.class)
@Retention(RetentionPolicy.RUNTIME)
public @interface Tag {
    String value();

    @Retention(RetentionPolicy.RUNTIME)
    @interface List { Tag[] value(); }
}

@Inherited
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface Marker {}
```

```java
@Tag("alpha") @Tag("beta")
static final class Tagged extends Candidate { /* ... */ }
```

#results(
  ("Tagged.class.getAnnotation(Tag.class)", "null"),
  ("Tagged.class.getAnnotation(Tag.List.class)", "@sa4e.reflect.Tag.List({@sa4e.reflect.Tag(\"alpha\"), @sa4e.reflect.Tag(\"beta\")})"),
  ("Tagged.class.getAnnotationsByType(Tag.class)", "[@sa4e.reflect.Tag(\"alpha\"), @sa4e.reflect.Tag(\"beta\")]"),
  ("Tagged.class.getAnnotation(Marker.class)", "@sa4e.reflect.Marker() (inherited: @Marker is @Inherited)"),
  ("Tagged.class.getAnnotation(Comment.class)", "null (not inherited: @Comment is not)"),
  ("Tagged.class.getDeclaredAnnotation(Marker.class)", "null (declared on Tagged itself: no)"),
)

Writing `@Tag` twice is syntactic sugar. The compiler wraps the repeats into one container annotation, `@Tag.List`, which is why `getAnnotation(Tag.class)` finds nothing and `getAnnotation(Tag.List.class)` finds both. `getAnnotationsByType` unwraps the container for you; use it whenever an annotation is repeatable.

`@Inherited` makes a _class_ annotation visible on subclasses: `Tagged` never says `@Marker`, but `getAnnotation(Marker.class)` finds the one on `Candidate`. `@Comment` is not `@Inherited`, so it stays with `Candidate`. Two fine points: `@Inherited` works only for class-level annotations, never for methods or fields, and `getDeclaredAnnotation` ignores inheritance altogether and reports only what is written on the class itself.

== Annotations are interfaces; instances are proxies

One more look at `onClass`, the `@Comment` read from `Candidate`:

#results(
  ("onClass.getClass().getName()", "jdk.proxy2.$Proxy1"),
  ("Proxy.isProxyClass(onClass.getClass())", "true"),
  ("onClass.annotationType()", "interface sa4e.reflect.Comment"),
  ("onClass instanceof Annotation", "true"),
  ("onClass.equals(getX.getAnnotation(Comment.class))", "false"),
)

Nobody wrote a class that implements `Comment`. Yet `onClass` is an object, and `onClass.value()` returns a string. The object's class is called `$Proxy1`, and it was generated by the JVM when the annotation was first read, using `java.lang.reflect.Proxy`. That mechanism is the subject of stage 04; for now, note that annotations are not magic either. Also note the last line: two annotations are `equals` when their members are equal, and these two have different `value`s.

== Framework one: declarative validation

Now the payoff. `@NotNull` and `@Range` are annotations with `RUNTIME` retention and targets `FIELD` and `PARAMETER`. `Validator` is a class that knows nothing about `Candidate`, or about any other class it will ever check:

```java
public static List<String> validate(Object target) throws IllegalAccessException {
    List<String> violations = new ArrayList<>();
    for (Class<?> k = target.getClass(); k != null; k = k.getSuperclass()) {
        for (Field f : k.getDeclaredFields()) {
            if (Modifier.isStatic(f.getModifiers())) continue;
            f.setAccessible(true);
            Object value = f.get(target);

            if (f.isAnnotationPresent(NotNull.class) && value == null) {
                violations.add(f.getName() + " must not be null");
            }
            Range range = f.getAnnotation(Range.class);
            if (range != null && value instanceof Number number) {
                long v = number.longValue();
                if (v < range.min() || v > range.max()) {
                    violations.add(f.getName() + " = " + v
                            + " is outside [" + range.min() + ", " + range.max() + "]");
                }
            }
        }
    }
    return violations;
}
```
#src[stage03-annotations/src/main/java/sa4e/reflect/Validator.java]

Every line is something from an earlier stage: the superclass walk, `getDeclaredFields`, `setAccessible`, `Field.get`, and now `getAnnotation`. Applied to a healthy and an unhealthy `Candidate`:

#results(
  ("Validator.validate(new Candidate(7))", "[]"),
  ("Validator.validate(candidate with x=1000, label=null)", "[x = 1000 is outside [-100, 100], label must not be null]"),
)

(The unhealthy one had `label` set to `null` by reflection, because no constructor of `Candidate` allows it. Reflection breaks invariants as easily as it checks them.)

The point is where the knowledge lives. The rule "x must be between -100 and 100" sits on the field `x`, in `Candidate.java`, next to the thing it constrains. The code that enforces it is generic and shared. This is Jakarta Bean Validation in thirty lines; the real thing has hundreds of constraints, message interpolation, groups and cascading, but the shape is identical. Every web framework's form binding is this loop.

== Framework two: a test runner

The second framework introduces the idea the rest of the book is built on. Three annotations:

```java
@Retention(RUNTIME) @Target(METHOD) public @interface Test {}
@Retention(RUNTIME) @Target(METHOD) public @interface BeforeEach {}
@Retention(RUNTIME) @Target(METHOD)
public @interface Disabled { String value() default ""; }
```

a test class that uses them and never calls its own methods:

```java
public class CandidateTests {
    private Candidate c;

    @BeforeEach
    void setUp() { c = new Candidate(7); }

    @Test
    void negativeDKeepsY() { c.f(3, -1.0); assertEquals(3, c.getX()); }

    @Test
    void positiveDNegatesY() { c.f(3, 1.0); assertEquals(-3, c.getX()); }

    @Test
    void resetSetsFortyTwo() { c.reset(); assertEquals(42, c.getX()); }

    @Test
    void deliberateFailure() { assertEquals(8, c.getX()); }   // wrong on purpose

    @Test @Disabled("waiting for stage 04")
    void notYet() {}

    private static void assertEquals(int expected, int actual) {
        if (expected != actual)
            throw new AssertionError("expected " + expected + " but was " + actual);
    }
}
```

and a runner:

```java
public static List<Result> run(Class<?> testClass) throws ReflectiveOperationException {
    Method[] methods = testClass.getDeclaredMethods();
    Arrays.sort(methods, Comparator.comparing(Method::getName));   // no order promised
    List<Method> setups = new ArrayList<>();
    List<Method> tests = new ArrayList<>();
    for (Method m : methods) {
        m.setAccessible(true);                       // tests are usually package-private
        if (m.isAnnotationPresent(BeforeEach.class)) setups.add(m);
        if (m.isAnnotationPresent(Test.class)) tests.add(m);
    }

    List<Result> results = new ArrayList<>();
    for (Method test : tests) {
        Disabled disabled = test.getAnnotation(Disabled.class);
        if (disabled != null) {
            results.add(new Result(test.getName(), "skipped", disabled.value()));
            continue;
        }
        Object instance = testClass.getDeclaredConstructor().newInstance(); // fresh
        try {
            for (Method setup : setups) setup.invoke(instance);
            test.invoke(instance);
            results.add(new Result(test.getName(), "passed", ""));
        } catch (InvocationTargetException e) {                    // the test threw: unwrap
            Throwable cause = e.getCause();
            results.add(new Result(test.getName(), "failed",
                    cause.getClass().getSimpleName() + ": " + cause.getMessage()));
        }
    }
    return results;
}
```
#src[stage03-annotations/src/main/java/sa4e/reflect/TestRunner.java]

#table(
  columns: (auto, auto, 1fr),
  [Test], [Outcome], [Detail],
  [#m("deliberateFailure")], [failed], [AssertionError: expected 8 but was 7],
  [#m("negativeDKeepsY")], [passed], [],
  [#m("notYet")], [skipped], [waiting for stage 04],
  [#m("positiveDNegatesY")], [passed], [],
  [#m("resetSetsFortyTwo")], [passed], [],
)

Every mechanical detail is familiar by now: find methods, read annotations, create an instance, invoke, unwrap `InvocationTargetException`. What is new is the _direction of control_. `CandidateTests` is a class with five methods that nobody in `CandidateTests` ever calls. The runner decides what to create, in what order to call what, and what a failure means. The test class only _declares_, through annotations, which methods matter.

That reversal, where the framework calls your code instead of your code calling the framework, has a name: _inversion of control_, sometimes summarised as the Hollywood principle, "don't call us, we'll call you". JUnit is this runner with lifecycle extensions, parameter resolution and a reporting API. Servlet containers, message listeners, GUI event loops and, in stage 06, dependency-injection containers all work this way. Stage 03 is where the book's title quietly changes from "reflection" to "and more".

#wild[
  - Jakarta Bean Validation (`@NotNull`, `@Min`, `@Max`, `@Size`) is the validator with hundreds of constraints and message interpolation.
  - JUnit 5 is the test runner with extension points; `@BeforeEach`, `@Test` and `@Disabled` are its real names.
  - JPA (`@Entity`, `@Column`), Jackson (`@JsonProperty`), Spring (`@Component`, `@Transactional`) and Jakarta REST (`@GET`, `@Path`) are all "framework reads annotation, framework acts". Stages 04 and 06 build two of them.
  - Annotations with `CLASS` or `SOURCE` retention feed annotation processors at compile time (Lombok, MapStruct, Dagger), which generate code instead of reflecting at run time.
]

#bill[
  - Annotations are declarations, not behaviour. Nothing happens unless some code reads them; a forgotten framework call silently ignores every constraint, and the compiler cannot tell you.
  - The same annotation can mean different things to different frameworks, and the order in which frameworks process them is expressed nowhere.
  - Reading annotations is reflection, with stage 02's costs. Frameworks scan once at startup and cache.
  - Forgetting `@Retention(RUNTIME)` is the single most common annotation bug, and its symptom is a silent `null`.
]

#tryit[
  + Add `@Size(min, max)` for strings and collections to `Validator`.
  + Let `TestRunner` support `@AfterEach`, and run only the tests whose names are given on the command line.
  + Give `@Comment` a second member `author` with a default, and find out whether an annotation instance can tell which of its members were defaulted. (It cannot. Where could the information come from?)
  + Declare an annotation with `SOURCE` retention and verify with `javap -v` that it is absent from the class file; then do the same for `CLASS` retention and find it in `RuntimeInvisibleAnnotations`.
]

#takeaway[
  - An annotation is an interface with `@Target` and `@Retention`; its members are parameterless methods with optional defaults.
  - Only `RUNTIME` retention is visible to reflection. `CLASS` is the default and is stored but invisible; `SOURCE` never leaves `javac`.
  - `getAnnotation`, `isAnnotationPresent` and `getAnnotationsByType` work on every `AnnotatedElement`; annotation instances are generated proxies.
  - A framework is a loop over reflection plus annotations: find the annotated elements, then act. The validator and the test runner are that loop.
  - When the framework calls your code, that is inversion of control.
]
