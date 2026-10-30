package sa4e.reflect;

import java.lang.invoke.MethodHandle;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.MethodType;
import java.lang.reflect.Array;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.InaccessibleObjectException;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Parameter;

/**
 * Stage 02: reflection.
 * <p>
 * Stage 01 only asked a class what it is. Now the program reads the structure of a class it
 * does not know, creates objects, calls methods and changes fields, all by name and all at
 * run time. Visibility is a compile-time concept; reflection can set it aside for our own
 * classes, but not for the JDK's.
 */
public final class Main {

    public static void main(String[] args) throws Throwable {   // MethodHandle.invokeExact declares Throwable
        System.out.println("Java " + Runtime.version() + ", " + System.getProperty("java.vm.name")
                + " (" + System.getProperty("java.vendor") + "), " + System.getProperty("java.home"));
        System.out.println();

        section("1. Inspector: describing a class without knowing it");
        new Inspector(Candidate.class).print(System.out);
        System.out.println();
        System.out.println("Candidate.class.getDeclaredMethods().length = " + Candidate.class.getDeclaredMethods().length
                + "   (all methods declared in Candidate, any visibility)");
        System.out.println("Candidate.class.getMethods().length         = " + Candidate.class.getMethods().length
                + "   (public methods only, but including those inherited from Object)");
        System.out.println("Special.class.getDeclaredMethods().length   = " + Special.class.getDeclaredMethods().length
                + "   (compareTo plus a synthetic bridge method generated for Comparable<Special>)");
        note("The same Inspector works for any class, including the JDK's: try new Inspector(java.util.HashMap.class).");

        section("2. Parameter names survive only if the compiler is told to keep them");
        Method f = Candidate.class.getMethod("f", int.class, double.class);
        for (Parameter p : f.getParameters()) {
            System.out.println("parameter " + p.getName() + " : " + p.getType().getSimpleName()
                    + "   (isNamePresent=" + p.isNamePresent() + ")");
        }
        note("This project compiles with -parameters. Without it the names are arg0, arg1 and frameworks such as");
        note("Spring MVC could not map ?x=... request parameters to method parameters by name.");

        section("3. Creating objects by name");
        Class<?> type = Class.forName("sa4e.reflect.Candidate");
        Object viaPublic = type.getConstructor(int.class).newInstance(7);
        System.out.println("public constructor Candidate(int)        -> " + viaPublic);
        Constructor<?> hidden = type.getDeclaredConstructor(String.class);
        hidden.setAccessible(true);                                     // private: setAccessible is needed
        Object viaPrivate = hidden.newInstance("made by reflection");
        System.out.println("private constructor Candidate(String)    -> " + viaPrivate);
        note("getConstructor finds only public constructors, getDeclaredConstructor finds all of them.");

        section("4. Calling methods by name");
        Candidate c = new Candidate(1);
        Candidate.class.getMethod("f", int.class, double.class).invoke(c, 3, -1.0);
        System.out.println("after f(3, -1.0) via reflection          -> " + c);
        Method secret = Candidate.class.getDeclaredMethod("secret");
        secret.setAccessible(true);
        System.out.println("private secret()                         -> " + secret.invoke(c));
        Method created = Candidate.class.getMethod("created");
        System.out.println("static created(), target null            -> " + created.invoke(null));
        try {
            Integer.class.getMethod("parseInt", String.class).invoke(null, "forty-two");
        } catch (InvocationTargetException e) {
            System.out.println("exception thrown inside the method       -> InvocationTargetException wrapping "
                    + e.getCause());
        }
        try {
            secret.invoke("not a Candidate");
        } catch (IllegalArgumentException e) {
            System.out.println("wrong target object                      -> IllegalArgumentException: " + e.getMessage());
        }
        note("Arguments and return values are passed as Object; primitives are boxed and unboxed automatically.");

        section("5. Reading and writing fields, even private and final ones");
        Field x = Candidate.class.getDeclaredField("x");
        Field label = Candidate.class.getDeclaredField("label");
        x.setAccessible(true);
        label.setAccessible(true);
        System.out.println("x.getInt(c)                              -> " + x.getInt(c));
        System.out.println("label.get(c)                             -> " + label.get(c));
        label.set(c, "changed although final");                     // allowed for instance fields of normal classes
        System.out.println("after label.set(...)                     -> " + c);
        Field counter = Candidate.class.getDeclaredField("created");
        counter.setAccessible(true);
        counter.setInt(null, 1000);                                     // static field: target is null
        System.out.println("static created set to 1000               -> Candidate.created() = " + Candidate.created());
        Variant.A record = new Variant.A(1, "one");
        Field value = Variant.A.class.getDeclaredField("value");
        value.setAccessible(true);
        try {
            value.setInt(record, 2);
        } catch (IllegalAccessException e) {
            System.out.println("record component field                   -> IllegalAccessException: " + e.getMessage());
        }
        note("Records, hidden classes and static final fields are off limits even with setAccessible(true).");
        note("Final instance fields of normal classes can be changed, which serialization frameworks rely on.");

        section("6. The wall: strong encapsulation of the JDK (since Java 9, enforced since 16)");
        Field stringValue = String.class.getDeclaredField("value");
        System.out.println("String.class.getDeclaredField(\"value\")  -> " + stringValue + "   (reading metadata always works)");
        try {
            stringValue.setAccessible(true);
        } catch (InaccessibleObjectException e) {
            System.out.println("stringValue.setAccessible(true)          -> InaccessibleObjectException");
            System.out.println("   " + e.getMessage());
        }
        note("java.base does not 'open' java.lang to us. Start the JVM with --add-opens java.base/java.lang=ALL-UNNAMED");
        note("to allow it. Many frameworks needed exactly such flags when Java 16 closed the door.");

        section("7. Arrays through reflection");
        Object array = Array.newInstance(Candidate.class, 2);          // Candidate[2], type known only at run time
        Array.set(array, 0, new Candidate(5));
        Array.set(array, 1, viaPrivate);
        System.out.println("Array.newInstance(Candidate.class, 2)    -> " + array.getClass().getSimpleName()
                + " of length " + Array.getLength(array));
        System.out.println("Array.get(array, 1)                      -> " + Array.get(array, 1));

        section("8. Invoker: a convenience layer that picks the member by argument types");
        Object made = Invoker.newInstance("sa4e.reflect.Candidate", 9);
        System.out.println("Invoker.newInstance(\"...Candidate\", 9)   -> " + made);
        System.out.println("Invoker.call(made, \"secret\")             -> " + Invoker.call(made, "secret"));
        Invoker.call(made, "f", 4, 1.5);
        System.out.println("Invoker.call(made, \"f\", 4, 1.5)          -> " + made);
        System.out.println("Invoker.call(Candidate.class, \"created\") -> " + Invoker.call(Candidate.class, "created"));
        Invoker.set(made, "x", 77);
        System.out.println("Invoker.set(made, \"x\", 77)              -> " + Invoker.get(made, "x"));
        Special sp = new Special(3);
        System.out.println("Invoker.call(special, \"secret\")          -> " + Invoker.call(sp, "secret") + "   (inherited private method)");
        note("Member names as strings: no compile-time check, no help from the IDE when renaming. This is the price.");

        section("9. What does it cost? direct call vs. Method.invoke vs. MethodHandle");
        benchmark();
        note("Numbers are indicative only (no proper benchmark harness). Since Java 18 Method.invoke is itself built");
        note("on method handles (JEP 416); after warm-up the JIT removes most of the overhead for both.");
    }

    private static void benchmark() throws Throwable {
        // Several targets with different values, so the JIT cannot hoist the call out of the loop.
        Candidate[] targets = {new Candidate(1), new Candidate(2), new Candidate(3), new Candidate(4)};
        Method m = Candidate.class.getMethod("getX");
        MethodHandle mh = MethodHandles.lookup().findVirtual(Candidate.class, "getX", MethodType.methodType(int.class));
        final int n = 20_000_000;
        long direct = 0, reflective = 0, handle = 0, sum = 0;
        for (int round = 0; round < 3; round++) {                      // last round counts, earlier ones warm up the JIT
            long t0 = System.nanoTime();
            for (int i = 0; i < n; i++) sum += targets[i & 3].getX();
            long t1 = System.nanoTime();
            for (int i = 0; i < n; i++) sum += (int) m.invoke(targets[i & 3]);
            long t2 = System.nanoTime();
            for (int i = 0; i < n; i++) sum += (int) mh.invokeExact(targets[i & 3]);
            long t3 = System.nanoTime();
            direct = t1 - t0;
            reflective = t2 - t1;
            handle = t3 - t2;
        }
        System.out.printf("%,d calls each (checksum %d)%n", n, sum);
        System.out.printf("direct call      : %6.2f ns/call%n", (double) direct / n);
        System.out.printf("Method.invoke    : %6.2f ns/call%n", (double) reflective / n);
        System.out.printf("MethodHandle     : %6.2f ns/call%n", (double) handle / n);
    }

    private static void section(String title) {
        System.out.println();
        System.out.println("── " + title);
    }

    private static void note(String text) {
        System.out.println("   ℹ " + text);
    }
}
