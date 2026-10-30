package sa4e.reflect;

import java.lang.classfile.ClassFile;
import java.lang.classfile.ClassModel;
import java.lang.invoke.MethodHandles;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;

/**
 * Stage 07: generating classes at run time.
 * <p>
 * The JVM does not care where class bytes come from. Stage 05 compiled source code; this stage
 * skips the compiler and writes the class file directly with the ClassFile API. That is how
 * lambdas, dynamic proxies, CGLIB and ByteBuddy, Hibernate entity proxies and mocking
 * frameworks create the classes they need.
 */
public final class Main {

    public static void main(String[] args) throws Throwable {
        Report r = Report.stdout();
        r.title("Stage 07: generating classes at run time");

        r.heading("1. Reading bytecode: what the compiler made of Candidate.f");
        byte[] candidateBytes = Candidate.class.getResourceAsStream("Candidate.class").readAllBytes();
        ClassModel candidate = Bytecode.parse(candidateBytes);
        r.kv("Candidate.class size", candidateBytes.length + " bytes");
        r.kv("major version", candidate.majorVersion() + " (Java " + (candidate.majorVersion() - 44) + ")");
        r.kv("methods", Bytecode.methods(candidate));
        r.code("", "public void f(int y, double d) { if (d < 0) x = y; else x = -y; }\n\n" + Bytecode.instructions(candidate, "f"));
        r.note("The ClassFile API (java.lang.classfile, final since Java 24) parses and writes class files. Locals live "
                + "in numbered slots: this = 0, y = 1, d = 2 and 3 (a double takes two). Every framework that generates "
                + "code works at this level, previously with the ASM library.");

        r.heading("2. Writing a class from nothing");
        String implName = "sa4e.reflect.Generated";
        byte[] implBytes = Generator.implementation(implName);
        r.kv("Generator.implementation(...) produced", implBytes.length + " bytes");
        r.kv("ClassFile.of().verify(bytes)", ClassFile.of().verify(implBytes).isEmpty() ? "no errors" : ClassFile.of().verify(implBytes).toString());
        ByteArrayClassLoader loader = new ByteArrayClassLoader();
        Class<?> generated = loader.define(implName, implBytes);
        Capability instance = (Capability) generated.getDeclaredConstructor().newInstance();
        instance.f(21, 0.0);
        r.kv("generated.getName()", generated.getName());
        r.kv("generated.getInterfaces()", Arrays.toString(generated.getInterfaces()));
        r.kv("instance.f(21, 0.0); instance.getX()", instance.getX());
        r.kv("instance.toString()", instance);
        r.kv("generated.getAnnotation(Comment.class).value()", generated.getAnnotation(Comment.class).value());
        r.code("", "generated f:\n" + Bytecode.instructions(Bytecode.parse(implBytes), "f"));
        r.note("No source file, no javac. The bytes went straight from the Generator into defineClass. Even the "
                + "@Comment annotation of stage 03 was written as a class file attribute and reads back as usual.");

        r.heading("3. A proxy for a class: the generated subclass stage 04 could not provide");
        String subName = "sa4e.reflect.Candidate$$Intercepted";
        byte[] subBytes = Generator.interceptingSubclass(subName);
        Class<?> intercepted = loader.define(subName, subBytes);
        Candidate c = (Candidate) intercepted.getConstructor(int.class).newInstance(7);
        c.f(3, -1.0);
        int x = c.getX();
        r.kv("intercepted.getSuperclass()", intercepted.getSuperclass());
        r.kv("c instanceof Candidate", c instanceof Candidate);
        r.kv("c.f(3, -1.0); c.getX()", x);
        r.kv("c (Candidate's own toString)", c);
        r.kv("Interceptor.CALLS", Interceptor.CALLS);
        r.code("", "generated getX:\n" + Bytecode.instructions(Bytecode.parse(subBytes), "getX"));
        r.note("The subclass overrides getX and f, reports to Interceptor and calls super. CGLIB and ByteBuddy "
                + "generate exactly such subclasses for Spring's class-based proxies and Hibernate's lazy entities. "
                + "Requirements follow: the class and the methods must not be final, and the superclass constructor runs.");

        r.heading("4. Hidden classes: how lambdas are defined");
        byte[] hiddenBytes = Generator.implementation("sa4e.reflect.Hidden");
        Class<?> hidden = MethodHandles.lookup().defineHiddenClass(hiddenBytes, true).lookupClass();
        Capability h = (Capability) hidden.getDeclaredConstructor().newInstance();
        r.kv("hidden.getName()", hidden.getName());
        r.kv("hidden.isHidden()", hidden.isHidden());
        r.kv("h.getX()", h.getX());
        try {
            Class.forName(hidden.getName());
        } catch (ClassNotFoundException e) {
            r.kv("Class.forName(hidden.getName())", "ClassNotFoundException");
        }
        r.note("A hidden class is defined through a Lookup, not a loader: it has no findable name, cannot be referenced "
                + "by other classes, and is unloaded with its last instance. Lambdas (stage 01, section 9) are hidden "
                + "classes spun by LambdaMetafactory.");

        r.heading("5. Looking at the result with javap");
        Path dir = Path.of(System.getProperty("java.io.tmpdir"), "reflect-generated");
        Files.createDirectories(dir);
        Path implFile = dir.resolve("Generated.class");
        Path subFile = dir.resolve("Candidate$$Intercepted.class");
        Files.write(implFile, implBytes);
        Files.write(subFile, subBytes);
        r.kv("written", implFile + " and " + subFile.getFileName());
        r.code("sh", "javap -c -p '" + implFile + "'");
        r.note("Generated classes are ordinary class files. Anything that reads class files, javap, decompilers, "
                + "the ClassFile API in section 1, can inspect them.");

        r.heading("6. The whole spectrum");
        r.item("Compile time: annotation processors (Lombok, MapStruct, Dagger, Hibernate metamodel) generate source "
                + "or class files during javac; no reflection at run time, but a build step.");
        r.item("Run time, from source: stage 05 and JSP engines call the compiler.");
        r.item("Run time, from bytes: this stage, java.lang.reflect.Proxy, lambdas, CGLIB, ByteBuddy, Mockito.");
        r.item("Ahead of time: GraalVM native image resolves everything at build time and needs a list of what will be "
                + "loaded, reflected on or proxied; dynamic generation at run time is not possible there.");
        r.item("The trend in Spring, Quarkus and Micronaut is to move from run-time reflection to build-time generation, "
                + "for startup time and memory; the concepts stay the same.");
        r.flush();
    }
}
