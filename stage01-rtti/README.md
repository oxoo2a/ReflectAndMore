# Stage 01: run-time type information

## Pain in stage 00

`Main` knows `Candidate` only because the compiler read `Candidate.java`. At run time the program
cannot say what kind of object it holds, cannot compare types, and cannot turn a class name that
arrives at run time into an object.

## Mechanism

Every object carries a reference to its class, and the class is an object of type `java.lang.Class`.
`Main` walks through what such a Class object can tell:

1. static type of a variable vs. dynamic type of the object (`getClass()`)
2. Class objects as values: `int.class`, `int[].class`, `Candidate.class`, names and identity
3. `Class.forName("sa4e.reflect.Candidate")`: from a string to a type to an instance
4. the type hierarchy: `getSuperclass()`, `getInterfaces()`
5. type tests and casts without the cast operator: `isAssignableFrom`, `isInstance`, `cast`
6. pattern matching over a sealed hierarchy (the compiler uses RTTI as well)
7. sealed types, records and enums describing themselves
8. type erasure, generic signatures of declarations, and the super type token (`TypeRef`)
9. lambdas and anonymous classes as classes

## New files

| File | Purpose |
|---|---|
| `Special.java` | subclass of `Candidate`, so static and dynamic type can differ |
| `Variant.java` | sealed interface with a record, a class and an enum |
| `TypeRef.java` | the super type token trick used by Jackson and Guice |

`Candidate.java` is unchanged.

## In the real world

- Every DI container starts with `isAssignableFrom` to find candidates for an interface.
- JDBC (`Class.forName("org.postgresql.Driver")`), JNDI, logging back-ends and plugin systems
  start with `Class.forName`.
- Jackson's `TypeReference<List<Customer>>` is `TypeRef`.

## Cost

Almost none: `getClass()` is a pointer dereference, `isInstance` is the same check as `instanceof`.
`Class.forName` triggers class loading and static initialisation, which can be expensive and has
side effects (that is exactly how JDBC drivers used to register themselves).

## Exercises

1. Print the full inheritance chain of `java.util.LinkedHashMap` including all interfaces.
2. Write a method `boolean sameHierarchy(Object a, Object b)` that returns true when one object's
   class is a subclass of the other's, without using `instanceof`.
3. Make `TypeRef` work for nested arguments such as `Map<String, List<Integer>>` and print the
   inner types recursively.

## Run

```
./run.sh 01
```
