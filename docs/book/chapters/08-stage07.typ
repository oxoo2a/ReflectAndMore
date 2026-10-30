#import "../template.typ": *

#chapter(num: "Stage 07", title: "Generating classes at run time", tagline: [In which we skip the compiler entirely, write a class one instruction at a time, and give `Candidate` a subclass it never asked for.])

== Where we stand

Two limits survived to the last stage. Dynamic proxies (stage 04) can only implement interfaces, so a class without an interface cannot be intercepted; that is why Spring asks for interfaces, and why it falls back to "CGLIB" when there are none. And run-time compilation (stage 05) needs source code and a compiler, which is slow and is not available on a plain JRE.

Frameworks need neither. They write class files directly. The JVM does not care where the bytes of a class come from, only that they are well-formed, and since Java 24 the JDK ships an official API for reading and writing them: `java.lang.classfile`. This chapter uses it to look at what the compiler produced, then to produce something of our own, and finally to do the one thing stage 04 could not.

== Reading bytecode

Before writing a class file, read one. `Bytecode.parse` wraps `ClassFile.of().parse(bytes)` and lists what it finds:

#results(
  ("Candidate.class size", "2393 bytes"),
  ("major version", "69 (Java 25)"),
  ("methods", "[<init>(int)void : 14 instructions, <init>()void : 6 instructions, <init>(String)void : 13 instructions, getX()int : 3 instructions, f(int,double)void : 13 instructions, reset()void : 4 instructions, secret()String : 4 instructions, created()int : 2 instructions, toString()String : 15 instructions]"),
)

Constructors are methods called `<init>`; the static counter's increment is why `Candidate(int)` has fourteen instructions. Here is `f`, source and bytecode side by side:

```java
public void f(int y, double d) { if (d < 0) x = y; else x = -y; }
```

```
dload_2
dconst_0
dcmpg
ifge
aload_0
iload_1
putfield sa4e/reflect/Candidate.x : int
goto
aload_0
iload_1
ineg
putfield sa4e/reflect/Candidate.x : int
return
```

The JVM is a stack machine with numbered local variable slots. In an instance method slot 0 is `this`, and the parameters follow: `y` in slot 1, `d` in slots 2 and 3, because a `double` takes two. `dload_2` pushes `d`, `dconst_0` pushes `0.0`, `dcmpg` compares them, `ifge` jumps to the `else` branch if the result is not negative. Each branch loads `this` and `y`, optionally negates, and stores into the field `x` with `putfield`. That is all a method is: a list of instructions over a stack and some slots. Every framework that generates code works at this level, for twenty years with the ASM library and now with the JDK's own API.

== Writing a class from nothing

`Generator.implementation` produces a complete `Capability` implementation without a line of Java source. In Java it would read:

```java
@Comment("generated at run time")
public final class Generated implements Capability {
    private int x;
    public int getX() { return x; }
    public void f(int y, double d) { x = y; }
    public String toString() { return "Generated{x=" + x + "}"; }
}
```

and with the ClassFile API it reads:

```java
ClassDesc self = ClassDesc.of("sa4e.reflect.Generated");
byte[] bytes = ClassFile.of().build(self, cb -> {
    cb.withFlags(ClassFile.ACC_PUBLIC | ClassFile.ACC_FINAL);
    cb.withSuperclass(CD_Object);
    cb.withInterfaceSymbols(ClassDesc.of("sa4e.reflect.Capability"));
    cb.with(RuntimeVisibleAnnotationsAttribute.of(Annotation.of(
            ClassDesc.of("sa4e.reflect.Comment"),
            AnnotationElement.ofString("value", "generated at run time"))));
    cb.withField("x", CD_int, ClassFile.ACC_PRIVATE);

    cb.withMethodBody(INIT_NAME, MTD_void, ClassFile.ACC_PUBLIC, code -> code
            .aload(0)
            .invokespecial(CD_Object, INIT_NAME, MTD_void)      // super();
            .return_());

    cb.withMethodBody("getX", MethodTypeDesc.of(CD_int), ClassFile.ACC_PUBLIC, code -> code
            .aload(0)
            .getfield(self, "x", CD_int)                        // this.x
            .ireturn());

    MethodTypeDesc fType = MethodTypeDesc.of(CD_void, CD_int, CD_double);
    cb.withMethodBody("f", fType, ClassFile.ACC_PUBLIC, code -> code
            .aload(0)
            .iload(1)                                           // y
            .putfield(self, "x", CD_int)                        // this.x = y
            .return_());
    // toString: new StringBuilder, append, append, toString; see the source
});
```
#src[stage07-codegen/src/main/java/sa4e/reflect/Generator.java (abridged)]

A `ClassDesc` names a class, a `MethodTypeDesc` names a signature, and the `code` builder has one method per JVM instruction. The result is a `byte[]`. To make it a class, we need the one thing stage 05's exercise asked for, a loader that exposes `defineClass`:

```java
public final class ByteArrayClassLoader extends ClassLoader {
    public ByteArrayClassLoader() {
        super("generated", ByteArrayClassLoader.class.getClassLoader());
    }

    public Class<?> define(String name, byte[] bytes) {
        return defineClass(name, bytes, 0, bytes.length);
    }
}
```

```java
Class<?> generated = loader.define("sa4e.reflect.Generated", bytes);
Capability instance = (Capability) generated.getDeclaredConstructor().newInstance();
```

#results(
  ("Generator.implementation(...) produced", "649 bytes"),
  ("ClassFile.of().verify(bytes)", "no errors"),
  ("generated.getName()", "sa4e.reflect.Generated"),
  ("generated.getInterfaces()", "[interface sa4e.reflect.Capability]"),
  ("instance.f(21, 0.0); instance.getX()", "21"),
  ("instance.toString()", "Generated{x=21}"),
  ("generated.getAnnotation(Comment.class).value()", "generated at run time"),
)

No source file, no `javac`, no temporary directory. Six hundred and forty-nine bytes went from `Generator` into `defineClass`, and out came a class that implements `Capability`, runs, and even carries the `@Comment` annotation of stage 03, written as a class-file attribute and read back by `getAnnotation` as if a compiler had put it there. `ClassFile.verify` runs the same structural checks the JVM would, so a mistake in the instruction sequence is reported before the class is defined rather than as a `VerifyError` at an unhelpful moment.

== A proxy for a class

Now the limit of stage 04. `Generator.interceptingSubclass` writes the class that CGLIB would write:

```java
public class Candidate$$Intercepted extends Candidate {
    public Candidate$$Intercepted(int x) { super(x); }
    public int getX() { Interceptor.before("getX"); return super.getX(); }
    public void f(int y, double d) { Interceptor.before("f"); super.f(y, d); }
}
```

where `Interceptor.before` is a static hook that records the call. The bytecode of the generated `getX`:

```
ldc getX
invokestatic sa4e/reflect/Interceptor.before(String)void
aload_0
invokespecial sa4e/reflect/Candidate.getX()int
ireturn
```

Push the string, call the hook, push `this`, call the superclass method with `invokespecial` (which is how `super.` is spelled in bytecode), return. And it behaves exactly as a hand-written subclass would:

#results(
  ("intercepted.getSuperclass()", "class sa4e.reflect.Candidate"),
  ("c instanceof Candidate", "true"),
  ("c.f(3, -1.0); c.getX()", "3"),
  ("c (Candidate's own toString)", "Candidate{x=3, label='candidate#7'}"),
  ("Interceptor.CALLS", "[f, getX]"),
)

`c instanceof Candidate` is `true` this time, which is the whole difference from stage 04. The generated object _is_ a `Candidate`, with `Candidate`'s fields, `Candidate`'s constructor having run, and `Candidate`'s `toString`. Code that asks for a `Candidate` rather than a `Capability` accepts it. This is what Spring does for a bean without an interface, what Hibernate does to make a lazily loaded entity look like the entity, and what Mockito does to mock a class.

The requirements follow from the mechanism. The class must not be `final`, the intercepted methods must not be `final` or `private` (a subclass cannot override them), and the superclass constructor runs, with whatever side effects it has; `Candidate.created()` went up by one. Every one of these appears in the documentation of every framework that generates subclasses, usually as a rule you are asked to follow without being told why.

== Hidden classes

Stage 01 ended with a lambda whose class was "hidden". Here is how such a class is made:

```java
byte[] bytes = Generator.implementation("sa4e.reflect.Hidden");
Class<?> hidden = MethodHandles.lookup().defineHiddenClass(bytes, true).lookupClass();
```

#results(
  ("hidden.getName()", "sa4e.reflect.Hidden/0x00001e000104bc00"),
  ("hidden.isHidden()", "true"),
  ("h.getX()", "0"),
  ("Class.forName(hidden.getName())", "ClassNotFoundException"),
)

A hidden class is defined through a `Lookup` rather than a loader. It has a name, but the name has a `/0x...` suffix that no other class can refer to and `Class.forName` cannot resolve; it lives in the same package as the lookup class; and it can be unloaded when its last instance is gone, independently of its loader. The JDK uses hidden classes for lambdas, for the proxies of stage 04 since Java 16, and for the glue classes behind `MethodHandle`. For a framework that generates thousands of small classes, "unloaded with the last instance" is the property that matters.

== Looking at the result with javap

Generated classes are ordinary class files, and the stage writes them to disk so that the standard tools can inspect them:

```sh
javap -c -p /tmp/reflect-generated/Generated.class
```

Anything that reads class files, `javap`, a decompiler, an IDE, or `Bytecode.parse` from the first section, treats them like any other. There is no mark that says "generated"; the name `Candidate$$Intercepted` is a convention, chosen so that it is visible in stack traces, and the double dollar is a tradition from CGLIB (`$$EnhancerByCGLIB$$`) that Spring, Hibernate and ByteBuddy kept.

== The whole spectrum

Step back from this chapter and look at all the ways code can be made to exist:

- *Compile time.* Annotation processors (Lombok, MapStruct, Dagger, the JPA metamodel) run inside `javac`, read `SOURCE`-retention annotations and generate source or class files. No reflection at run time, but a build step and a compiler plugin.
- *Run time, from source.* Stage 05, JSP engines and the Java shell call the compiler. Flexible, slow, needs a JDK.
- *Run time, from bytes.* This stage, `java.lang.reflect.Proxy`, lambdas, CGLIB, ByteBuddy and Mockito. Fast, needs no compiler, needs someone to write bytecode.
- *Ahead of time.* GraalVM native image resolves everything at build time and needs a complete list of what will be loaded, reflected on or proxied; dynamic generation at run time is simply not possible there.

The trend in Spring, Quarkus and Micronaut is to move from the third option towards the first and the fourth, trading run-time reflection for build-time generation, for faster startup and smaller memory. The concepts do not change; only the moment at which the decisions are made moves, which is where this book started.

#wild[
  - `java.lang.reflect.Proxy` (stage 04) and `LambdaMetafactory` (stage 01) generate classes like the second section, inside the JDK itself.
  - CGLIB, ByteBuddy and Javassist generate subclasses like the third section for Spring class proxies, Hibernate lazy entities, Mockito mocks and Jakarta CDI scoped beans.
  - Before Java 24 all of them used the ASM library; the JDK itself has been moving to the ClassFile API, which was in fact built to replace ASM inside the JDK.
  - Instrumentation agents (`java.lang.instrument`) use the same API to rewrite classes _as they are loaded_, which is how profilers and tracing agents work.
]

#bill[
  - Writing bytecode by hand is error-prone; the verifier catches structural mistakes, not logical ones. Frameworks keep this code small and test it exhaustively.
  - Generated classes complicate debugging and stack traces (`Candidate$$Intercepted`, `$$EnhancerBySpringCGLIB$$`) and are invisible to static analysis.
  - Each generated class costs metaspace; hidden classes help by dying with their last instance.
  - None of it works in a closed-world ahead-of-time build.
]

#tryit[
  + Extend `Generator.interceptingSubclass` so that the generated `getX` also reports the return value to `Interceptor`. (Hint: `dup` before the `invokestatic`.)
  + Generate the subclass for any class and any list of public non-final methods, with the list taken from reflection, and compare with stage 04's `LoggingHandler`.
  + Measure a call through the generated subclass against a stage 04 proxy and against a direct call.
  + Remove the `dload(2)` from `f` or swap two instructions on purpose and read what `ClassFile.verify` and then the JVM report.
]

#takeaway[
  - A class is bytes; the JVM accepts them from a compiler, from a generator or from a `Lookup`, as long as they verify.
  - The ClassFile API reads and writes class files; a method is a list of instructions over a stack and numbered slots.
  - A generated subclass is the class proxy that interfaces-only `Proxy` cannot provide; it requires non-final classes and methods.
  - Hidden classes are unnamed, unreferenceable and unloaded with their last instance; lambdas are hidden classes.
  - Code generation at compile time, at run time from source, at run time from bytes, and ahead of time are the same decisions made at different moments.
]
