# Stage 07: generating classes at run time

_Java 25+37-LTS-jvmci-b01, Java HotSpot(TM) 64-Bit Server VM (Oracle Corporation), /Users/sturm/.sdkman/candidates/java/25-graal_

## 1. Reading bytecode: what the compiler made of Candidate.f

| Expression             | Result                                                                                                                                                                                                                                                                                                      |
|------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Candidate.class size` | 2393 bytes                                                                                                                                                                                                                                                                                                  |
| `major version`        | 69 (Java 25)                                                                                                                                                                                                                                                                                                |
| `methods`              | [<init>(int)void : 14 instructions, <init>()void : 6 instructions, <init>(String)void : 13 instructions, getX()int : 3 instructions, f(int,double)void : 13 instructions, reset()void : 4 instructions, secret()String : 4 instructions, created()int : 2 instructions, toString()String : 15 instructions] |

```
public void f(int y, double d) { if (d < 0) x = y; else x = -y; }

dload_2
dconst_0 0.0
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

> ℹ The ClassFile API (java.lang.classfile, final since Java 24) parses and writes class files. Locals live in numbered slots: this = 0, y = 1, d = 2 and 3 (a double takes two). Every framework that generates code works at this level, previously with the ASM library.

## 2. Writing a class from nothing

| Expression                                       | Result                              |
|--------------------------------------------------|-------------------------------------|
| `Generator.implementation(...) produced`         | 649 bytes                           |
| `ClassFile.of().verify(bytes)`                   | no errors                           |
| `generated.getName()`                            | sa4e.reflect.Generated              |
| `generated.getInterfaces()`                      | [interface sa4e.reflect.Capability] |
| `instance.f(21, 0.0); instance.getX()`           | 21                                  |
| `instance.toString()`                            | Generated{x=21}                     |
| `generated.getAnnotation(Comment.class).value()` | generated at run time               |

```
generated f:
aload_0
iload_1
putfield sa4e/reflect/Generated.x : int
return
```

> ℹ No source file, no javac. The bytes went straight from the Generator into defineClass. Even the @Comment annotation of stage 03 was written as a class file attribute and reads back as usual.

## 3. A proxy for a class: the generated subclass stage 04 could not provide

| Expression                     | Result                              |
|--------------------------------|-------------------------------------|
| `intercepted.getSuperclass()`  | class sa4e.reflect.Candidate        |
| `c instanceof Candidate`       | true                                |
| `c.f(3, -1.0); c.getX()`       | 3                                   |
| `c (Candidate's own toString)` | Candidate{x=3, label='candidate#7'} |
| `Interceptor.CALLS`            | [f, getX]                           |

```
generated getX:
ldc getX
invokestatic sa4e/reflect/Interceptor.before(String)void
aload_0
invokespecial sa4e/reflect/Candidate.getX()int
ireturn
```

> ℹ The subclass overrides getX and f, reports to Interceptor and calls super. CGLIB and ByteBuddy generate exactly such subclasses for Spring's class-based proxies and Hibernate's lazy entities. Requirements follow: the class and the methods must not be final, and the superclass constructor runs.

## 4. Hidden classes: how lambdas are defined

| Expression                        | Result                                 |
|-----------------------------------|----------------------------------------|
| `hidden.getName()`                | sa4e.reflect.Hidden/0x000003e00104c000 |
| `hidden.isHidden()`               | true                                   |
| `h.getX()`                        | 0                                      |
| `Class.forName(hidden.getName())` | ClassNotFoundException                 |

> ℹ A hidden class is defined through a Lookup, not a loader: it has no findable name, cannot be referenced by other classes, and is unloaded with its last instance. Lambdas (stage 01, section 9) are hidden classes spun by LambdaMetafactory.

## 5. Looking at the result with javap

| Expression | Result                                                                                                              |
|------------|---------------------------------------------------------------------------------------------------------------------|
| `written`  | /var/folders/86/4z___jzs2dsdxdqh1vv4vpq80000gn/T/reflect-generated/Generated.class and Candidate$$Intercepted.class |

```sh
javap -c -p '/var/folders/86/4z___jzs2dsdxdqh1vv4vpq80000gn/T/reflect-generated/Generated.class'
```

> ℹ Generated classes are ordinary class files. Anything that reads class files, javap, decompilers, the ClassFile API in section 1, can inspect them.

## 6. The whole spectrum

- Compile time: annotation processors (Lombok, MapStruct, Dagger, Hibernate metamodel) generate source or class files during javac; no reflection at run time, but a build step.
- Run time, from source: stage 05 and JSP engines call the compiler.
- Run time, from bytes: this stage, java.lang.reflect.Proxy, lambdas, CGLIB, ByteBuddy, Mockito.
- Ahead of time: GraalVM native image resolves everything at build time and needs a list of what will be loaded, reflected on or proxied; dynamic generation at run time is not possible there.
- The trend in Spring, Quarkus and Micronaut is to move from run-time reflection to build-time generation, for startup time and memory; the concepts stay the same.
