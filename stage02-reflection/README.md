# Stage 02: reflection

## Pain in stage 01

Stage 01 could ask a class *what* it is, but not *what it contains*, and it could not do anything
with that knowledge: no object creation with arguments, no method call, no access to a field
unless everything was written down at compile time.

## Mechanism

`java.lang.reflect`: `Constructor`, `Field`, `Method`, `Parameter`, `Modifier`, `Array`.
Every member of a class is itself an object that can be listed, inspected and used.

`Main` walks through:

1. `Inspector`: an XML description of any class (the TalkAbout example from the slides),
   and the difference between `getDeclaredMethods()` and `getMethods()`
2. parameter names, which exist only because the project compiles with `-parameters`
3. creating objects by name, through public and private constructors
4. calling public, private and static methods; how exceptions are wrapped
5. reading and writing private and even final fields; where the JVM refuses (records)
6. the wall: `setAccessible` on `java.lang.String` fails because `java.base` is not opened
7. arrays whose component type is known only at run time
8. `Invoker`: a convenience layer that selects a member by the run-time types of the arguments
9. the cost of a reflective call compared with a direct call and a `MethodHandle`

## New files

| File | Purpose |
|---|---|
| `Inspector.java` | XML description of a class from its declared constructors, fields and methods |
| `Invoker.java` | `newInstance`, `call`, `get`, `set` by name, with argument-based member selection |

`Candidate.java` is unchanged. `Special` and `Variant` stay because `Main` uses them;
`TypeRef` from stage 01 is no longer needed and was dropped.

## In the real world

- Jackson and Gson read and write private fields of your classes exactly as in section 5.
- JUnit finds and invokes test methods as in section 4 (stage 03 adds the annotations).
- Spring and Jakarta CDI call constructors as in section 3 (stage 06).
- Mockito, Hibernate and serialization frameworks needed `--add-opens` flags, or had to be
  rewritten, when Java 16 made section 6 fail by default.

## Cost

- Member names are strings: no compile-time check, refactoring tools cannot follow them.
- A reflective call is several times slower than a direct one, although the JIT and the
  method-handle based implementation (JEP 416) narrow the gap considerably after warm-up.
- Reflection defeats encapsulation. Since Java 16 the JDK protects itself; your own modules can
  do the same with `module-info.java` by not opening packages.
- GraalVM native image needs a list of everything that is accessed reflectively
  (`reachability-metadata.json`), because the closed-world compiler cannot see the strings.

## Exercises

1. Let `Inspector` emit JSON instead of XML, and add the inherited public methods as a
   separate section.
2. `Invoker.call` cannot call `f(int, double)` with the arguments `(4, 1)`, because `1` is an
   `Integer` and the parameter is `double`. Add widening conversions.
3. Run `Main` with `--add-opens java.base/java.lang=ALL-UNNAMED` and change the content of a
   `String` in place. Then explain why string literals in the whole program may change too.
4. Replace `Method.invoke` in the benchmark by a lambda created with
   `LambdaMetafactory` and compare again.

## Run

```
./run.sh 02
```

The output is Markdown; see [output.md](output.md) for the result of the last run.
