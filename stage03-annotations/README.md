# Stage 03: annotations

## Pain in stage 02

Reflection lets a framework read a class, but the class cannot say anything back. Which field
must not be null? Which method is a test? Which parameter has a valid range? In stage 02 such
knowledge would have to live in the framework, in naming conventions or in external XML files.

## Mechanism

Annotations: structured metadata written next to the element it describes, checked by the
compiler and, with `RUNTIME` retention, readable through reflection.

`Main` walks through:

1. defining `@Comment` and reading it from a class, a method and a parameter
2. meta-annotations: `@Retention` and `@Target` are themselves annotations and can be read
3. `Inspector` listing all annotations of all elements without knowing any annotation type
4. retention: a probe class with `SOURCE`, `CLASS` and `RUNTIME` annotations, checked through
   reflection and through the bytes of the class file (ClassFile API, Java 24)
5. repeatable annotations and their container; `@Inherited` and `getDeclaredAnnotation`
6. annotations are interfaces, their instances are dynamic proxies (the bridge to stage 04)
7. a declarative validator: `@NotNull` and `@Range` checked by code that knows no classes
8. a test runner: `@Test`, `@BeforeEach`, `@Disabled`, the first taste of inversion of control

## New files

| File | Purpose |
|---|---|
| `Comment.java` | the annotation from the slides, with target and retention |
| `Marker.java` | an `@Inherited` annotation without members |
| `Tag.java` | a `@Repeatable` annotation with its container `Tag.List` |
| `Retentions.java` | three annotations differing only in retention, plus a probe class |
| `NotNull.java`, `Range.java`, `Validator.java` | a declarative validation framework |
| `Test.java`, `BeforeEach.java`, `Disabled.java`, `TestRunner.java` | a test framework |
| `CandidateTests.java` | tests for `Candidate`, one failing on purpose |

Changed: `Candidate.java` carries `@Comment`, `@Marker`, `@NotNull` and `@Range` now; its
behaviour is untouched. `Inspector.java` prints annotations, with the
annotation member values as element text (the StAX writer escapes them). `Invoker` from stage 02 is no
longer used and was dropped.

## In the real world

- Jakarta Bean Validation (`@NotNull`, `@Min`, `@Size`) is section 7 with hundreds of
  constraints and message interpolation.
- JUnit 5 is section 8 with lifecycle extensions, parameter resolution and reporting.
- JPA (`@Entity`, `@Column`), Jackson (`@JsonProperty`), Spring (`@Component`,
  `@Transactional`) and Jakarta REST (`@GET`, `@Path`) are all "framework reads annotation,
  framework acts". Stages 04 and 06 build two of them.
- Annotations with `CLASS` or `SOURCE` retention feed annotation processors at compile time
  (Lombok, MapStruct, Dagger), which generate code instead of using reflection.

## Cost

- Annotations are declarations, not behaviour. Nothing happens unless some code reads them;
  a forgotten framework call silently ignores every constraint.
- The same annotation can mean different things to different frameworks, and ordering or
  interaction between frameworks is not expressed anywhere.
- Reading annotations is reflection, with the same costs as in stage 02. Frameworks therefore
  scan once at startup and cache.

## Exercises

1. Add `@Size(min, max)` for strings and collections to the validator.
2. Let `TestRunner` support `@AfterEach`, and run tests whose names are given on the command line only.
3. Give `@Comment` a second member `author` with a default, and check which members of an
   annotation instance are defaults: the `Comment` proxy cannot tell, so where could the
   information come from?
4. Write an annotation with `SOURCE` retention and verify with `javap -v` that it is absent from
   the class file, then do the same for `CLASS` retention.

## Run

```
./run.sh 03
```

The output is Markdown; see [output.md](output.md) for the result of the last run.
