#import "../template.typ": *

#chapter(title: "Introduction", tagline: [In which we promise to take the magic out of enterprise Java, and introduce the most boring class ever written.])

== The small chill

Every Java developer has had the moment. You write a class, you put `@Component` on top of it, you declare a field with `@Inject` or `@Autowired`, and you never write `new`. The object simply _is there_ when you need it, with all its collaborators attached. You add `@Transactional` to a method and a database transaction wraps itself around every call. You add `@Test` and a method you never call is called for you. You return an object from a REST endpoint and it leaves the building as JSON.

It works, and it is wonderful, and somewhere in the back of your mind there is a small chill: _I have no idea how any of this happens._

This book is about that chill. In eight stages it builds, from nothing but the JDK, every mechanism that makes a modern application framework tick: run-time type information, reflection, annotations, dynamic proxies, dynamic class loading, a dependency-injection container, and finally classes written as raw bytecode while the program runs. At the end you will have a tiny Spring, a tiny JUnit, a tiny Hibernate proxy and a tiny RMI in a few hundred lines, and you will know exactly why they work and what they cost. Frameworks are not magic. They are reflection, annotations, proxies and class loaders, arranged with taste.

== Who this is for

You can program in Java. You know what an interface is, you have written a class with a constructor, and you have used a `List<String>`. You have probably used a framework and felt the chill. You have never, or hardly ever, called `getClass()` on purpose, and you have never defined your own annotation. That is the audience: people who are good at the language and have not yet looked under its floorboards.

Everything here is plain JDK 25. There are no third-party libraries, because a library would be another place for magic to hide. If a program in this book does something, you can open the source and see the whole mechanism.

== Meet Candidate

Textbooks love to explain reflection with a `Customer` class that has an `Order` with `LineItems`. We will not do that. A business domain is a distraction: half of your attention goes to wondering whether the discount logic is realistic, and the mechanism being explained gets the other half. So our protagonist is deliberately, proudly boring. It is called `Candidate`, because it is the candidate for whatever we do next: inspection, interrogation, wiretapping, cloning.

```java
public class Candidate {

    private static int created;        // counts instances

    private int x;
    private final String label;

    public Candidate(int x) {
        this.x = x;
        this.label = "candidate#" + x;
        created++;
    }

    public Candidate() {
        this(0);
        reset();
    }

    private Candidate(String label) {  // only reachable from inside the class
        this.x = -1;
        this.label = label;
        created++;
    }

    public int getX() { return x; }

    public void f(int y, double d) {
        if (d < 0) x = y; else x = -y;
    }

    protected void reset() { x = 42; }

    private String secret() { return "the secret of " + label; }

    public static int created() { return created; }

    @Override
    public String toString() {
        return "Candidate{x=" + x + ", label='" + label + "'}";
    }
}
```
#src[stage00-plain/src/main/java/sa4e/reflect/Candidate.java]

That is all there is. Three constructors of three visibilities, a private field, a private final field, a static counter, a public method with two parameters, a protected method, a private method, a static method. There is nothing to understand about what `Candidate` _does_, which leaves all your attention for what we do _to_ it. Everything else in the book is named after its role in the mechanism: `Inspector`, `Invoker`, `Validator`, `Interceptor`, `Container`, `Plugin`, `Dependency`. When you later meet Spring's `BeanFactory` or Hibernate's `LazyInitializer`, you will recognise the roles.

`Candidate` changes as little as possible from stage to stage. It gains an annotation here, an interface there, an injected field near the end, and each change is announced. Everything that grows is the framework around it.

== How the book and the code fit together

The code lives in a repository with one folder per stage:

```
ReflectAndMore/
  stage00-plain/        stage04-proxies/
  stage01-rtti/         stage05-loading/
  stage02-reflection/   stage06-ioc/
  stage03-annotations/  stage07-codegen/
```

Each folder is a complete, runnable program. All of them use the same package `sa4e.reflect` and the same entry point `sa4e.reflect.Main`, so the difference between two neighbouring folders is exactly one lecture step; `tools/diff-stages.sh 03` shows what stage 03 added to stage 02. Run a stage with nothing but a JDK:

```sh
./run.sh 03
```

Every program prints Markdown. In the terminal that reads fine; redirected into a file it becomes a document with headings and tables, and each stage folder contains such a file, `output.md`, from the last run. The output excerpts in this book are taken from those files, so what you read here is what the program really printed.

Every chapter follows the same rhythm, because every stage does:

+ *Where we stand.* A concrete limitation of the previous stage. Not a philosophical one; a line of code that cannot be written.
+ *The mechanism.* The JDK API that removes the limitation, in the smallest form that works, walking through the sections of the stage's `Main`.
+ *In the wild.* Which framework does this for a living, and how far our toy is from the real thing.
+ *The bill.* What it costs: performance, security, debuggability, build-time tooling.
+ *Try it yourself.* Exercises. The best way to believe that a container is 150 lines is to add a feature to it.

== The map

#table(
  columns: (auto, 1fr, 1.3fr),
  align: (left, left, left),
  [Stage], [Question it answers], [Mechanism],
  [00 plain], [What does the program look like without any meta-programming?], [Nothing yet. Compile-time binding.],
  [01 rtti], [What does the JVM know about `Candidate` at run time?], [`Class` objects, hierarchy, `Class.forName`, sealed types, records, erasure],
  [02 reflection], [Can a program read and operate `Candidate` without knowing it at compile time?], [`Inspector`, `Invoker`, private access, the encapsulation wall, `MethodHandle`],
  [03 annotations], [How does `Candidate` tell a framework something extra?], [`@Comment`, retention, repeatable and inherited annotations, a validator, a test runner],
  [04 proxies], [How do we add behaviour around `Candidate` without touching it?], [`java.lang.reflect.Proxy`, handler chains, transactions, lazy loading, remote stubs],
  [05 loading], [How does code arrive that did not exist at compile time?], [Class loaders, configuration, `ServiceLoader`, run-time compilation, class identity],
  [06 ioc], [Who creates `Candidate` and fills its dependencies?], [A container with scanning, injection, scopes, cycles, an event bus],
  [07 codegen], [What if the class itself is written at run time?], [ClassFile API, generated subclasses, hidden classes],
)

The stages are cumulative in understanding, not always in code. A helper class travels forward only while a later stage still uses it, so each folder stays focused on its own idea.

== A note on tone

We will be unkind to `Candidate`'s privacy. We will read its private fields, call its private methods, change a field it declared `final`, and in the last chapter we will write a subclass of it in raw bytecode without asking. None of this is bad practice in itself; it is _exactly_ what Jackson, JUnit, Spring and Hibernate do to your classes every day. The point of doing it by hand once is that you will afterwards know when a framework is doing it to you, and what it means when the JVM says no.

Let us begin where every program begins: with nothing happening at all.
