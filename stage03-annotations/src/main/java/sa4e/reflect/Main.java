package sa4e.reflect;

import java.lang.annotation.Annotation;
import java.lang.annotation.Retention;
import java.lang.annotation.Target;
import java.lang.classfile.Attributes;
import java.lang.classfile.ClassFile;
import java.lang.classfile.ClassModel;
import java.lang.reflect.Method;
import java.lang.reflect.Parameter;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Stage 03: annotations.
 * <p>
 * Reflection lets a framework read a class. Annotations let the class talk back: structured
 * metadata, written next to the element it describes, checked by the compiler and (with RUNTIME
 * retention) readable through reflection. Two tiny frameworks show the pattern: a validator and
 * a test runner.
 */
public final class Main {

    /** Carries repeated tags; inherits @Marker from Candidate but not @Comment. */
    @Tag("alpha")
    @Tag("beta")
    static final class Tagged extends Candidate {
        Tagged() {
            super(1);
        }
    }

    public static void main(String[] args) throws Exception {
        Report r = Report.stdout();
        r.title("Stage 03: annotations");

        r.heading("1. Defining an annotation and reading it back");
        r.code("java", """
                @Retention(RetentionPolicy.RUNTIME)
                @Target({ElementType.TYPE, ElementType.CONSTRUCTOR, ElementType.FIELD, ElementType.METHOD, ElementType.PARAMETER})
                public @interface Comment {
                    String value() default "";
                }
                """);
        Comment onClass = Candidate.class.getAnnotation(Comment.class);
        r.kv("Candidate.class.getAnnotation(Comment.class).value()", onClass.value());
        Method getX = Candidate.class.getMethod("getX");
        r.kv("getX.getAnnotation(Comment.class).value()", getX.getAnnotation(Comment.class).value());
        r.kv("Candidate.class.getMethod(\"f\", ...).isAnnotationPresent(Comment.class)",
                Candidate.class.getMethod("f", int.class, double.class).isAnnotationPresent(Comment.class));
        try {
            Candidate.class.getMethod("reset");
        } catch (NoSuchMethodException e) {
            r.kv("Candidate.class.getMethod(\"reset\")", "NoSuchMethodException (getMethod sees public methods only; use getDeclaredMethod)");
        }
        Parameter y = Candidate.class.getMethod("f", int.class, double.class).getParameters()[0];
        Range yRange = y.getAnnotation(Range.class);
        r.kv("parameter y of f: getAnnotation(Range.class)", "min=" + yRange.min() + ", max=" + yRange.max());
        r.note("Classes, constructors, fields, methods and parameters are all AnnotatedElements. "
                + "An annotation is read with getAnnotation(Type.class); absent annotations yield null.");

        r.heading("2. Meta-annotations: annotations describing annotations");
        r.kv("Comment.class.isAnnotation()", Comment.class.isAnnotation());
        r.kv("Comment.class.getAnnotation(Retention.class).value()", Comment.class.getAnnotation(Retention.class).value());
        r.kv("Comment.class.getAnnotation(Target.class).value()", Arrays.toString(Comment.class.getAnnotation(Target.class).value()));
        r.kv("Comment.class.getDeclaredMethods()", Arrays.toString(Comment.class.getDeclaredMethods()));
        r.note("@Target is enforced by the compiler: writing @Comment on a local variable is a compile error. "
                + "Members of an annotation are declared as methods without parameters; defaults are part of the declaration.");

        r.heading("3. Inspector now lists annotations without knowing any of them");
        r.code("xml", new Inspector(Candidate.class).describe());
        r.note("Inspector calls getAnnotations() on each element and reads the members of each annotation reflectively "
                + "(a.annotationType().getDeclaredMethods(), then invoke). It needs no import of Comment, Range or NotNull.");

        r.heading("4. Retention: who can see the annotation?");
        r.kv("Retentions.Probe is declared with", "@SourceOnly @ClassOnly @RuntimeOnly");
        r.kv("Retentions.Probe.class.getAnnotations()", Arrays.toString(Retentions.Probe.class.getAnnotations()));
        byte[] bytes = Retentions.Probe.class.getResourceAsStream("Retentions$Probe.class").readAllBytes();
        ClassModel model = ClassFile.of().parse(bytes);
        List<String> visible = model.findAttribute(Attributes.runtimeVisibleAnnotations())
                .map(a -> a.annotations().stream().map(x -> x.classSymbol().displayName()).toList()).orElse(List.of());
        List<String> invisible = model.findAttribute(Attributes.runtimeInvisibleAnnotations())
                .map(a -> a.annotations().stream().map(x -> x.classSymbol().displayName()).toList()).orElse(List.of());
        r.kv("class file attribute RuntimeVisibleAnnotations", visible);
        r.kv("class file attribute RuntimeInvisibleAnnotations", invisible);
        r.note("Read with the ClassFile API (java.lang.classfile, since Java 24) from the bytes of Probe.class: "
                + "CLASS retention is stored but invisible to reflection, SOURCE retention never leaves javac. "
                + "CLASS is the default and is what bytecode tools and static analysers read.");

        r.heading("5. Repeatable and inherited annotations");
        r.kv("Tagged is declared with", "@Tag(\"alpha\") @Tag(\"beta\"), extends Candidate");
        r.kv("Tagged.class.getAnnotation(Tag.class)", Tagged.class.getAnnotation(Tag.class));
        r.kv("Tagged.class.getAnnotation(Tag.List.class)", Tagged.class.getAnnotation(Tag.List.class));
        r.kv("Tagged.class.getAnnotationsByType(Tag.class)", Arrays.toString(Tagged.class.getAnnotationsByType(Tag.class)));
        r.kv("Tagged.class.getAnnotation(Marker.class)", Tagged.class.getAnnotation(Marker.class) + " (inherited: @Marker is @Inherited)");
        r.kv("Tagged.class.getAnnotation(Comment.class)", Tagged.class.getAnnotation(Comment.class) + " (not inherited: @Comment is not)");
        r.kv("Tagged.class.getDeclaredAnnotation(Marker.class)", Tagged.class.getDeclaredAnnotation(Marker.class) + " (declared on Tagged itself: no)");
        r.note("Repeats are wrapped into the container annotation; getAnnotationsByType unwraps them. "
                + "@Inherited works for class annotations only, never for methods or fields.");

        r.heading("6. Annotations are interfaces, their instances are dynamic proxies");
        r.kv("onClass.getClass().getName()", onClass.getClass().getName());
        r.kv("Proxy.isProxyClass(onClass.getClass())", Proxy.isProxyClass(onClass.getClass()));
        r.kv("onClass.annotationType()", onClass.annotationType());
        r.kv("onClass instanceof Annotation", onClass instanceof Annotation);
        r.kv("onClass.equals(getX.getAnnotation(Comment.class))", onClass.equals(getX.getAnnotation(Comment.class)));
        r.note("Nobody wrote a class implementing Comment. The JVM generates one at run time with java.lang.reflect.Proxy, "
                + "which is the subject of stage 04.");

        r.heading("7. A framework built on annotations: declarative validation");
        Candidate good = new Candidate(7);
        r.kv("Validator.validate(new Candidate(7))", Validator.validate(good));
        Candidate bad = new Candidate(1000);
        java.lang.reflect.Field label = Candidate.class.getDeclaredField("label");
        label.setAccessible(true);
        label.set(bad, null);                                            // only reflection can break the invariant
        r.kv("Validator.validate(candidate with x=1000, label=null)", Validator.validate(bad));
        r.note("Validator imports neither Candidate nor any other checked class. The constraints live where the data lives. "
                + "Jakarta Bean Validation, Spring's @Validated and every web framework's form binding work like this.");

        r.heading("8. A framework built on annotations: a test runner");
        List<String[]> rows = new ArrayList<>();
        for (TestRunner.Result result : TestRunner.run(CandidateTests.class)) {
            rows.add(new String[]{"`" + result.test() + "`", result.outcome(), result.detail()});
        }
        r.table(new String[]{"Test", "Outcome", "Detail"}, rows);
        r.note("CandidateTests never calls its own methods. The runner finds @Test methods, creates a fresh instance "
                + "for each, runs @BeforeEach first and unwraps the exception of a failing test. JUnit 5 is this "
                + "idea with extension points. The runner calls the tests, not the other way round: inversion of control.");
        r.flush();
    }
}
