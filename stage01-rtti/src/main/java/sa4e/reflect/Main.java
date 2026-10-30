package sa4e.reflect;

import java.lang.reflect.Field;
import java.lang.reflect.RecordComponent;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Stage 01: run-time type information (RTTI).
 * <p>
 * Every object carries a reference to its class, and that class is itself an object of type
 * {@link Class}. Class objects can be compared, stored, passed around, obtained from a string,
 * and asked about their place in the type hierarchy. Nothing is read or changed yet; that is
 * stage 02.
 */
public final class Main {

    /** Only used to show the difference between a field's erased type and its generic type. */
    static class Holder {
        List<String> items = new ArrayList<>();
        Map<String, List<Integer>> index = Map.of();
    }

    public static void main(String[] args) throws Exception {

        section("1. Static type vs. dynamic type");
        Candidate c = new Special(7);                       // static type Candidate, dynamic type Special
        System.out.println("declared type of variable c : Candidate");
        System.out.println("c.getClass()                : " + c.getClass());
        System.out.println("c.getClass().getName()      : " + c.getClass().getName());
        System.out.println("c instanceof Special        : " + (c instanceof Special));
        note("The compiler only knows 'Candidate'. The JVM knows the real class of every object,");
        note("because every object header points to its class metadata. getClass() just follows that pointer.");

        section("2. Class objects are ordinary values");
        Class<?>[] samples = {int.class, Integer.class, int[].class, String[][].class, Candidate.class,
                Special.class, Variant.class, Variant.A.class, Variant.Mode.class, Runnable.class, void.class};
        System.out.printf("%-26s %-16s %-26s %s%n", "getName()", "getSimpleName()", "getCanonicalName()", "kind");
        for (Class<?> k : samples) {
            System.out.printf("%-26s %-16s %-26s %s%n", k.getName(), k.getSimpleName(), k.getCanonicalName(), kind(k));
        }
        System.out.println("Candidate.class == c.getClass()            : " + (Candidate.class == c.getClass()));
        System.out.println("Candidate.class == new Candidate().getClass(): " + (Candidate.class == new Candidate().getClass()));
        note("There is exactly one Class object per loaded class, so == works. int.class is not Integer.class,");
        note("arrays are classes too ('[I' is int[]), and nested classes use '$' in getName().");

        section("3. From a string to a type: Class.forName()");
        Class<?> byName = Class.forName("sa4e.reflect.Candidate");
        Object instance = byName.getDeclaredConstructor().newInstance();
        System.out.println("Class.forName(\"sa4e.reflect.Candidate\") -> " + byName);
        System.out.println("new instance via reflection             -> " + instance);
        try {
            Class.forName("Candidate");
        } catch (ClassNotFoundException e) {
            System.out.println("Class.forName(\"Candidate\")             -> ClassNotFoundException (package is part of the name)");
        }
        note("This is the door through which configuration files, plugins, JDBC drivers and");
        note("dependency-injection containers enter a running program (stages 05 and 06).");

        section("4. Walking the type hierarchy");
        StringBuilder chain = new StringBuilder();
        for (Class<?> k = Special.class; k != null; k = k.getSuperclass()) {
            chain.append(k.getSimpleName()).append(k.getSuperclass() != null ? " -> " : "");
        }
        System.out.println("superclass chain of Special : " + chain);
        System.out.println("Special.getInterfaces()     : " + Arrays.toString(Special.class.getInterfaces()));
        System.out.println("all interfaces of ArrayList : " + allInterfaces(ArrayList.class).stream().map(Class::getSimpleName).toList());
        System.out.println("Object.getSuperclass()      : " + Object.class.getSuperclass());

        section("5. Type tests and casts through Class objects");
        System.out.println("Candidate.class.isAssignableFrom(Special.class) : " + Candidate.class.isAssignableFrom(Special.class));
        System.out.println("Special.class.isAssignableFrom(Candidate.class) : " + Special.class.isAssignableFrom(Candidate.class));
        System.out.println("Special.class.isInstance(c)                     : " + Special.class.isInstance(c));
        Special s = Special.class.cast(c);                  // the reflective form of (Special) c
        System.out.println("Special.class.cast(c).getX()                    : " + s.getX());
        try {
            Variant.A.class.cast(c);
        } catch (ClassCastException e) {
            System.out.println("Variant.A.class.cast(c)                         : ClassCastException");
        }
        note("isAssignableFrom and isInstance are what a container uses to find 'all components that implement X'.");

        section("6. Pattern matching: the compiler uses RTTI too");
        for (Variant v : List.of(new Variant.A(1, "one"), new Variant.B(2.5))) {
            String text = switch (v) {                       // no default branch needed: Variant is sealed
                case Variant.A a -> "A with value " + a.value() + " and tag " + a.tag();
                case Variant.B b -> "B with weight " + b.weight();
            };
            System.out.println(v.getClass().getSimpleName() + " is " + text);
        }
        note("instanceof and switch patterns are compiled to type checks against the object's class.");

        section("7. Sealed types, records and enums describe themselves");
        System.out.println("Variant.class.isSealed()          : " + Variant.class.isSealed());
        System.out.println("Variant.getPermittedSubclasses()  : " + Arrays.stream(Variant.class.getPermittedSubclasses()).map(Class::getSimpleName).toList());
        System.out.println("Variant.A.class.isRecord()        : " + Variant.A.class.isRecord());
        System.out.println("Variant.A.getRecordComponents()   : " + components(Variant.A.class));
        System.out.println("Variant.B.class.isRecord()        : " + Variant.B.class.isRecord());
        System.out.println("Variant.Mode.class.isEnum()       : " + Variant.Mode.class.isEnum());
        System.out.println("Variant.Mode.getEnumConstants()   : " + Arrays.toString(Variant.Mode.class.getEnumConstants()));
        note("Record components are the reason records are so convenient for generic serializers (stage 02).");

        section("8. Generics are erased from objects, but declarations keep their signatures");
        System.out.println("new ArrayList<String>().getClass() == new ArrayList<Integer>().getClass() : "
                + (new ArrayList<String>().getClass() == new ArrayList<Integer>().getClass()));
        Field items = Holder.class.getDeclaredField("items");
        Field index = Holder.class.getDeclaredField("index");
        System.out.println("field items: getType() = " + items.getType().getSimpleName() + ", getGenericType() = " + items.getGenericType());
        System.out.println("field index: getType() = " + index.getType().getSimpleName() + ", getGenericType() = " + index.getGenericType());
        TypeRef<List<String>> ref = new TypeRef<>() {};
        System.out.println("new TypeRef<List<String>>() {}.type()  = " + ref.type());
        note("The ArrayList object does not know it is a List<String>; the field and the anonymous subclass declaration do.");

        section("9. Lambdas and anonymous classes have classes too");
        Runnable lambda = () -> {};
        Runnable anonymous = new Runnable() {
            @Override
            public void run() {}
        };
        System.out.println("lambda    : " + lambda.getClass().getName()
                + "  hidden=" + lambda.getClass().isHidden() + " synthetic=" + lambda.getClass().isSynthetic());
        System.out.println("anonymous : " + anonymous.getClass().getName()
                + "  anonymous=" + anonymous.getClass().isAnonymousClass());
        note("Lambda classes are generated at run time and are 'hidden': Class.forName() cannot find them.");
        note("Stage 07 generates classes the same way.");
    }

    private static String kind(Class<?> k) {
        if (k.isPrimitive()) return "primitive";
        if (k.isArray()) return "array of " + k.getComponentType().getSimpleName();
        if (k.isRecord()) return "record";
        if (k.isEnum()) return "enum";
        if (k.isSealed()) return "sealed interface";
        if (k.isInterface()) return "interface";
        return "class";
    }

    private static String components(Class<?> record) {
        StringBuilder sb = new StringBuilder();
        for (RecordComponent rc : record.getRecordComponents()) {
            if (!sb.isEmpty()) sb.append(", ");
            sb.append(rc.getName()).append(": ").append(rc.getType().getSimpleName());
        }
        return sb.toString();
    }

    private static Set<Class<?>> allInterfaces(Class<?> k) {
        Set<Class<?>> result = new LinkedHashSet<>();
        for (Class<?> t = k; t != null; t = t.getSuperclass()) {
            for (Class<?> i : t.getInterfaces()) {
                result.add(i);
                result.addAll(allInterfaces(i));
            }
        }
        return result;
    }

    private static void section(String title) {
        System.out.println();
        System.out.println("── " + title);
    }

    private static void note(String text) {
        System.out.println("   ℹ " + text);
    }
}
