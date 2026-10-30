# Stage 01: run-time type information

_Java 25+37-LTS-jvmci-b01, Java HotSpot(TM) 64-Bit Server VM (Oracle Corporation), /Users/sturm/.sdkman/candidates/java/25-graal_

## 1. Static type vs. dynamic type

| Expression                     | Result                     |
|--------------------------------|----------------------------|
| `Candidate c = new Special(7)` | declared type Candidate    |
| `c.getClass()`                 | class sa4e.reflect.Special |
| `c.getClass().getName()`       | sa4e.reflect.Special       |
| `c instanceof Special`         | true                       |

> ℹ The compiler only knows 'Candidate'. The JVM knows the real class of every object, because every object header points to its class metadata. getClass() just follows that pointer.

## 2. Class objects are ordinary values

| getName()                   | getSimpleName() | getCanonicalName()        | kind              |
|-----------------------------|-----------------|---------------------------|-------------------|
| `int`                       | int             | int                       | primitive         |
| `java.lang.Integer`         | Integer         | java.lang.Integer         | class             |
| `[I`                        | int[]           | int[]                     | array of int      |
| `[[Ljava.lang.String;`      | String[][]      | java.lang.String[][]      | array of String[] |
| `sa4e.reflect.Candidate`    | Candidate       | sa4e.reflect.Candidate    | class             |
| `sa4e.reflect.Special`      | Special         | sa4e.reflect.Special      | class             |
| `sa4e.reflect.Variant`      | Variant         | sa4e.reflect.Variant      | sealed interface  |
| `sa4e.reflect.Variant$A`    | A               | sa4e.reflect.Variant.A    | record            |
| `sa4e.reflect.Variant$Mode` | Mode            | sa4e.reflect.Variant.Mode | enum              |
| `java.lang.Runnable`        | Runnable        | java.lang.Runnable        | interface         |
| `void`                      | void            | void                      | primitive         |

| Expression                                      | Result |
|-------------------------------------------------|--------|
| `Candidate.class == c.getClass()`               | false  |
| `Candidate.class == new Candidate().getClass()` | true   |

> ℹ There is exactly one Class object per loaded class, so == works. int.class is not Integer.class, arrays are classes too ('[I' is int[]), and nested classes use '$' in getName().

## 3. From a string to a type: Class.forName()

| Expression                                      | Result                                                   |
|-------------------------------------------------|----------------------------------------------------------|
| `Class.forName("sa4e.reflect.Candidate")`       | class sa4e.reflect.Candidate                             |
| `byName.getDeclaredConstructor().newInstance()` | Candidate{x=42, label='candidate#0'}                     |
| `Class.forName("Candidate")`                    | ClassNotFoundException (the package is part of the name) |

> ℹ This is the door through which configuration files, plugins, JDBC drivers and dependency-injection containers enter a running program (stages 05 and 06).

## 4. Walking the type hierarchy

| Expression                                   | Result                                                                                   |
|----------------------------------------------|------------------------------------------------------------------------------------------|
| `superclass chain of Special`                | Special -> Candidate -> Object                                                           |
| `Special.class.getInterfaces()`              | [interface java.lang.Comparable]                                                         |
| `all interfaces of ArrayList (transitively)` | [List, SequencedCollection, Collection, Iterable, RandomAccess, Cloneable, Serializable] |
| `Object.class.getSuperclass()`               | null                                                                                     |

## 5. Type tests and casts through Class objects

| Expression                                        | Result             |
|---------------------------------------------------|--------------------|
| `Candidate.class.isAssignableFrom(Special.class)` | true               |
| `Special.class.isAssignableFrom(Candidate.class)` | false              |
| `Special.class.isInstance(c)`                     | true               |
| `Special.class.cast(c).getX()`                    | 7                  |
| `Variant.A.class.cast(c)`                         | ClassCastException |

> ℹ isAssignableFrom and isInstance are what a container uses to find 'all components that implement X'.

## 6. Pattern matching: the compiler uses RTTI too

| Expression           | Result                     |
|----------------------|----------------------------|
| `switch (v) for a A` | A with value 1 and tag one |
| `switch (v) for a B` | B with weight 2.5          |

> ℹ instanceof and switch patterns are compiled to type checks against the object's class.

## 7. Sealed types, records and enums describe themselves

| Expression                               | Result                  |
|------------------------------------------|-------------------------|
| `Variant.class.isSealed()`               | true                    |
| `Variant.class.getPermittedSubclasses()` | [A, B]                  |
| `Variant.A.class.isRecord()`             | true                    |
| `Variant.A.class.getRecordComponents()`  | value: int, tag: String |
| `Variant.B.class.isRecord()`             | false                   |
| `Variant.Mode.class.isEnum()`            | true                    |
| `Variant.Mode.class.getEnumConstants()`  | [ON, OFF, UNKNOWN]      |

> ℹ Record components are the reason records are so convenient for generic serializers (stage 02).

## 8. Generics are erased from objects, but declarations keep their signatures

| Expression                                                                  | Result                                                             |
|-----------------------------------------------------------------------------|--------------------------------------------------------------------|
| `new ArrayList<String>().getClass() == new ArrayList<Integer>().getClass()` | true                                                               |
| `field items: getType()`                                                    | List                                                               |
| `field items: getGenericType()`                                             | java.util.List<java.lang.String>                                   |
| `field index: getType()`                                                    | Map                                                                |
| `field index: getGenericType()`                                             | java.util.Map<java.lang.String, java.util.List<java.lang.Integer>> |
| `new TypeRef<List<String>>() {}.type()`                                     | java.util.List<java.lang.String>                                   |

> ℹ The ArrayList object does not know it is a List<String>; the field declaration and the anonymous subclass declaration do. Jackson's TypeReference uses this trick.

## 9. Lambdas and anonymous classes have classes too

| Expression                                | Result                                       |
|-------------------------------------------|----------------------------------------------|
| `lambda.getClass().getName()`             | sa4e.reflect.Main$$Lambda/0x00007fff01046660 |
| `lambda.getClass().isHidden()`            | true                                         |
| `anonymous.getClass().getName()`          | sa4e.reflect.Main$2                          |
| `anonymous.getClass().isAnonymousClass()` | true                                         |

> ℹ Lambda classes are generated at run time and are 'hidden': Class.forName() cannot find them. Stage 07 generates classes the same way.
