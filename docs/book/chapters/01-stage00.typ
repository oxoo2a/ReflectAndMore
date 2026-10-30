#import "../template.typ": *

#chapter(num: "Stage 00", title: "Plain Java", tagline: [In which nothing happens, and that is the point.])

== The program

Stage 00 uses `Candidate` the way every Java program uses every class. It creates two instances, calls a method, prints the results. There is no trick, which makes it the baseline against which every later trick is measured.

```java
public final class Main {

    public static void main(String[] args) {
        Report r = Report.stdout();
        r.title("Stage 00: plain Java");

        Candidate a = new Candidate(7);
        Candidate b = new Candidate();
        a.f(3, -1.0);

        r.heading("Using Candidate the ordinary way");
        r.kv("a = new Candidate(7); a.f(3, -1.0)", a);
        r.kv("b = new Candidate()", b);
        r.kv("Candidate.created()", Candidate.created());

        r.heading("What this program cannot do");
        r.item("describe Candidate (fields, constructors, methods) without its source");
        r.item("call secret() or the private constructor");
        r.item("create an instance of a class whose name is known only at run time");
        r.item("decorate, replace or wire Candidate without editing Main");
        r.flush();
    }
}
```
#src[stage00-plain/src/main/java/sa4e/reflect/Main.java]

`Report` is a small helper that prints Markdown: a title, headings, `kv` for an expression and its result, `item` for bullet points. It is identical in every stage and has nothing to do with the material; think of it as `System.out.println` in a nicer suit. The output:

#results(
  ("a = new Candidate(7); a.f(3, -1.0)", "Candidate{x=3, label='candidate#7'}"),
  ("b = new Candidate()", "Candidate{x=42, label='candidate#0'}"),
  ("Candidate.created()", "2"),
)

Two candidates, one with `x` set by `f` because `d` was negative, one reset to 42 by the no-arg constructor. Nothing you could not have predicted by reading the source. That is the whole point of stage 00: _everything_ about this program was decided by reading source.

== What the compiler decided

It is worth being precise about what "decided at compile time" means, because the rest of the book is about moving decisions from that moment to a later one.

When `javac` compiles `a.f(3, -1.0)`, it has `Candidate.java` in front of it. It looks up `f`, checks that there is a method of that name taking an `int` and a `double`, checks that `f` is visible from `Main` (it is public), and emits an instruction. Run `javap -c` on the compiled `Main` and you see it:

```
28: aload_2
29: iconst_3
30: ldc2_w        #25     // double -1.0d
33: invokevirtual #27     // Method sa4e/reflect/Candidate.f:(ID)V
```

Three things in these four lines matter for everything that follows.

First, the _check_ happened at compile time. If `f` were private, `javac` would have refused, and no class file would exist. Visibility is, first of all, a compiler concept.

Second, the _binding_ to the name `f` is still symbolic. The instruction does not say "jump to address 0x4a20"; it says "call the method `f` with descriptor `(ID)V` on class `sa4e/reflect/Candidate`". The class file keeps names. The JVM resolves that name when the instruction first runs, by looking into the loaded `Candidate` class. Keep this in mind: the names survive compilation, which is the reason reflection is possible at all. A C++ compiler would have thrown them away.

Third, the name is a _literal_ in `Main`'s constant pool. `Main` can only ever call methods whose names were typed into `Main.java`. It cannot call a method whose name arrives in a configuration file, and it cannot create an instance of a class whose name arrives over the network.

== Four things this program cannot do

The second half of `Main` lists them, and each one is a job that some framework does for a living.

*Describe Candidate without reading its source.* A debugger, a JSON serializer, an object-relational mapper and a test runner all need to know what fields and methods a class has, for a class they have never seen. In stage 00 the only description of `Candidate` is the hand-written `toString()`, which is wrong the moment someone adds a field and forgets to update it. Stages 01 and 02 fix this.

*Call `secret()` or the private constructor.* The compiler says no, and that is usually right. But a serializer must set private fields when it reads JSON, a test may need to construct an object through a constructor the author hid, and a dependency-injection container needs to fill a private field without a setter. Stage 02 shows how the door opens, and where the JVM has put a wall.

*Create an instance of a class named at run time.* `new Candidate(7)` requires the word `Candidate` in the source. A plugin system, a JDBC driver manager, a configuration file saying `implementation=com.acme.FastSorter`, all need to go from a string to an object. Stages 01 and 05 are about that door.

*Decorate, replace or wire Candidate without editing Main.* To log every call to `f`, Main would have to call a logging wrapper instead. To run `f` inside a transaction, Main would have to begin and commit it. To give `Candidate` a collaborator, Main must create both and hand one to the other. In stage 00 Main does all the wiring by hand, and in a real program Main becomes a thousand lines of `new`. Stages 04 and 06 take that job away from Main.

#note[
  Notice that none of the four is about `Candidate` being badly designed. `Candidate` is fine. The limitations are limitations of _compile-time binding_: every decision is made by `javac` from source text, and `javac` is long gone when the program runs. Meta-programming is the art of making some of those decisions later, with information that only exists later.
]

== Where the names live

One experiment is worth doing right now, because it foreshadows everything. Compile stage 00 and run the JDK's disassembler on `Candidate` itself:

```sh
./run.sh 00 > /dev/null          # compiles into stage00-plain/out/classes
javap -p -cp stage00-plain/out/classes sa4e.reflect.Candidate
```

```
public class sa4e.reflect.Candidate {
  private static int created;
  private int x;
  private final java.lang.String label;
  public sa4e.reflect.Candidate(int);
  public sa4e.reflect.Candidate();
  private sa4e.reflect.Candidate(java.lang.String);
  public int getX();
  public void f(int, double);
  protected void reset();
  private java.lang.String secret();
  public static int created();
  public java.lang.String toString();
}
```

Every name, every type, every modifier is in the class file, private ones included. `javap` is not doing anything clever; it reads a well-documented binary format. If a command-line tool can read this, so can a running program, and in the next two stages it will.

#takeaway[
  - In plain Java, every decision about which class, which method and which field is made by the compiler from source text.
  - The compiled class file still contains all names, types and modifiers. Compilation hides nothing; it only fixes the decisions.
  - The four things stage 00 cannot do, describing, reaching private members, creating by name, and wiring without editing `Main`, are exactly the jobs of serializers, test runners, plugin systems and containers.
]
