# Stage 03: annotations

_Java 25+37-LTS-jvmci-b01, Java HotSpot(TM) 64-Bit Server VM (Oracle Corporation), /Users/sturm/.sdkman/candidates/java/25-graal_

## 1. Defining an annotation and reading it back

```java
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.CONSTRUCTOR, ElementType.FIELD, ElementType.METHOD, ElementType.PARAMETER})
public @interface Comment {
    String value() default "";
}
```

| Expression                                                               | Result                                                                            |
|--------------------------------------------------------------------------|-----------------------------------------------------------------------------------|
| `Candidate.class.getAnnotation(Comment.class).value()`                   | the class under investigation                                                     |
| `getX.getAnnotation(Comment.class).value()`                              | reads x                                                                           |
| `Candidate.class.getMethod("f", ...).isAnnotationPresent(Comment.class)` | false                                                                             |
| `Candidate.class.getMethod("reset")`                                     | NoSuchMethodException (getMethod sees public methods only; use getDeclaredMethod) |
| `parameter y of f: getAnnotation(Range.class)`                           | min=-10, max=10                                                                   |

> ℹ Classes, constructors, fields, methods and parameters are all AnnotatedElements. An annotation is read with getAnnotation(Type.class); absent annotations yield null.

## 2. Meta-annotations: annotations describing annotations

| Expression                                             | Result                                                          |
|--------------------------------------------------------|-----------------------------------------------------------------|
| `Comment.class.isAnnotation()`                         | true                                                            |
| `Comment.class.getAnnotation(Retention.class).value()` | RUNTIME                                                         |
| `Comment.class.getAnnotation(Target.class).value()`    | [TYPE, CONSTRUCTOR, FIELD, METHOD, PARAMETER]                   |
| `Comment.class.getDeclaredMethods()`                   | [public abstract java.lang.String sa4e.reflect.Comment.value()] |

> ℹ @Target is enforced by the compiler: writing @Comment on a local variable is a compile error. Members of an annotation are declared as methods without parameters; defaults are part of the declaration.

## 3. Inspector now lists annotations without knowing any of them

```xml
<?xml version="1.0" encoding="UTF-8"?>
<class name="sa4e.reflect.Candidate" modifiers="public" superclass="java.lang.Object">
  <annotation type="sa4e.reflect.Comment">
    <member name="value">the class under investigation</member>
  </annotation>
  <annotation type="sa4e.reflect.Marker"/>
  <constructor modifiers="private">
    <parameter name="label" type="java.lang.String"/>
  </constructor>
  <constructor modifiers="public">
  </constructor>
  <constructor modifiers="public">
    <parameter name="x" type="int"/>
  </constructor>
  <field name="created" type="int" modifiers="private static"/>
  <field name="label" type="java.lang.String" modifiers="private final">
    <annotation type="sa4e.reflect.NotNull"/>
  </field>
  <field name="x" type="int" modifiers="private">
    <annotation type="sa4e.reflect.Range">
      <member name="max">100</member>
      <member name="min">-100</member>
    </annotation>
  </field>
  <method name="created" modifiers="public static" returns="int">
  </method>
  <method name="f" modifiers="public" returns="void">
    <parameter name="y" type="int">
      <annotation type="sa4e.reflect.Range">
        <member name="max">10</member>
        <member name="min">-10</member>
      </annotation>
    </parameter>
    <parameter name="d" type="double"/>
  </method>
  <method name="getX" modifiers="public" returns="int">
    <annotation type="sa4e.reflect.Comment">
      <member name="value">reads x</member>
    </annotation>
  </method>
  <method name="reset" modifiers="protected" returns="void">
  </method>
  <method name="secret" modifiers="private" returns="java.lang.String">
  </method>
  <method name="toString" modifiers="public" returns="java.lang.String">
  </method>
</class>
```

> ℹ Inspector calls getAnnotations() on each element and reads the members of each annotation reflectively (a.annotationType().getDeclaredMethods(), then invoke). It needs no import of Comment, Range or NotNull.

## 4. Retention: who can see the annotation?

| Expression                                         | Result                                   |
|----------------------------------------------------|------------------------------------------|
| `Retentions.Probe is declared with`                | @SourceOnly @ClassOnly @RuntimeOnly      |
| `Retentions.Probe.class.getAnnotations()`          | [@sa4e.reflect.Retentions.RuntimeOnly()] |
| `class file attribute RuntimeVisibleAnnotations`   | [Retentions$RuntimeOnly]                 |
| `class file attribute RuntimeInvisibleAnnotations` | [Retentions$ClassOnly]                   |

> ℹ Read with the ClassFile API (java.lang.classfile, since Java 24) from the bytes of Probe.class: CLASS retention is stored but invisible to reflection, SOURCE retention never leaves javac. CLASS is the default and is what bytecode tools and static analysers read.

## 5. Repeatable and inherited annotations

| Expression                                         | Result                                                                          |
|----------------------------------------------------|---------------------------------------------------------------------------------|
| `Tagged is declared with`                          | @Tag("alpha") @Tag("beta"), extends Candidate                                   |
| `Tagged.class.getAnnotation(Tag.class)`            | null                                                                            |
| `Tagged.class.getAnnotation(Tag.List.class)`       | @sa4e.reflect.Tag.List({@sa4e.reflect.Tag("alpha"), @sa4e.reflect.Tag("beta")}) |
| `Tagged.class.getAnnotationsByType(Tag.class)`     | [@sa4e.reflect.Tag("alpha"), @sa4e.reflect.Tag("beta")]                         |
| `Tagged.class.getAnnotation(Marker.class)`         | @sa4e.reflect.Marker() (inherited: @Marker is @Inherited)                       |
| `Tagged.class.getAnnotation(Comment.class)`        | null (not inherited: @Comment is not)                                           |
| `Tagged.class.getDeclaredAnnotation(Marker.class)` | null (declared on Tagged itself: no)                                            |

> ℹ Repeats are wrapped into the container annotation; getAnnotationsByType unwraps them. @Inherited works for class annotations only, never for methods or fields.

## 6. Annotations are interfaces, their instances are dynamic proxies

| Expression                                          | Result                         |
|-----------------------------------------------------|--------------------------------|
| `onClass.getClass().getName()`                      | jdk.proxy2.$Proxy1             |
| `Proxy.isProxyClass(onClass.getClass())`            | true                           |
| `onClass.annotationType()`                          | interface sa4e.reflect.Comment |
| `onClass instanceof Annotation`                     | true                           |
| `onClass.equals(getX.getAnnotation(Comment.class))` | false                          |

> ℹ Nobody wrote a class implementing Comment. The JVM generates one at run time with java.lang.reflect.Proxy, which is the subject of stage 04.

## 7. A framework built on annotations: declarative validation

| Expression                                              | Result                                                    |
|---------------------------------------------------------|-----------------------------------------------------------|
| `Validator.validate(new Candidate(7))`                  | []                                                        |
| `Validator.validate(candidate with x=1000, label=null)` | [x = 1000 is outside [-100, 100], label must not be null] |

> ℹ Validator imports neither Candidate nor any other checked class. The constraints live where the data lives. Jakarta Bean Validation, Spring's @Validated and every web framework's form binding work like this.

## 8. A framework built on annotations: a test runner

| Test                | Outcome | Detail                               |
|---------------------|---------|--------------------------------------|
| `deliberateFailure` | failed  | AssertionError: expected 8 but was 7 |
| `negativeDKeepsY`   | passed  |                                      |
| `notYet`            | skipped | waiting for stage 04                 |
| `positiveDNegatesY` | passed  |                                      |
| `resetSetsFortyTwo` | passed  |                                      |

> ℹ CandidateTests never calls its own methods. The runner finds @Test methods, creates a fresh instance for each, runs @BeforeEach first and unwraps the exception of a failing test. JUnit 5 is this idea with extension points. The runner calls the tests, not the other way round: inversion of control.
