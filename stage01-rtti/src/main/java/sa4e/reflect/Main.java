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
        Report r = Report.stdout();
        r.title("Stage 01: run-time type information");

        r.heading("1. Static type vs. dynamic type");
        Candidate c = new Special(7);                       // static type Candidate, dynamic type Special
        r.kv("Candidate c = new Special(7)", "declared type Candidate");
        r.kv("c.getClass()", c.getClass());
        r.kv("c.getClass().getName()", c.getClass().getName());
        r.kv("c instanceof Special", c instanceof Special);
        r.note("The compiler only knows 'Candidate'. The JVM knows the real class of every object, because every "
                + "object header points to its class metadata. getClass() just follows that pointer.");

        r.heading("2. Class objects are ordinary values");
        Class<?>[] samples = {int.class, Integer.class, int[].class, String[][].class, Candidate.class,
                Special.class, Variant.class, Variant.A.class, Variant.Mode.class, Runnable.class, void.class};
        List<String[]> rows = new ArrayList<>();
        for (Class<?> k : samples) {
            rows.add(new String[]{"`" + k.getName() + "`", k.getSimpleName(), String.valueOf(k.getCanonicalName()), kind(k)});
        }
        r.table(new String[]{"getName()", "getSimpleName()", "getCanonicalName()", "kind"}, rows);
        r.kv("Candidate.class == c.getClass()", Candidate.class == c.getClass());
        r.kv("Candidate.class == new Candidate().getClass()", Candidate.class == new Candidate().getClass());
        r.note("There is exactly one Class object per loaded class, so == works. int.class is not Integer.class, "
                + "arrays are classes too ('[I' is int[]), and nested classes use '$' in getName().");

        r.heading("3. From a string to a type: Class.forName()");
        Class<?> byName = Class.forName("sa4e.reflect.Candidate");
        Object instance = byName.getDeclaredConstructor().newInstance();
        r.kv("Class.forName(\"sa4e.reflect.Candidate\")", byName);
        r.kv("byName.getDeclaredConstructor().newInstance()", instance);
        try {
            Class.forName("Candidate");
        } catch (ClassNotFoundException e) {
            r.kv("Class.forName(\"Candidate\")", "ClassNotFoundException (the package is part of the name)");
        }
        r.note("This is the door through which configuration files, plugins, JDBC drivers and "
                + "dependency-injection containers enter a running program (stages 05 and 06).");

        r.heading("4. Walking the type hierarchy");
        StringBuilder chain = new StringBuilder();
        for (Class<?> k = Special.class; k != null; k = k.getSuperclass()) {
            chain.append(k.getSimpleName()).append(k.getSuperclass() != null ? " -> " : "");
        }
        r.kv("superclass chain of Special", chain);
        r.kv("Special.class.getInterfaces()", Arrays.toString(Special.class.getInterfaces()));
        r.kv("all interfaces of ArrayList (transitively)", allInterfaces(ArrayList.class).stream().map(Class::getSimpleName).toList());
        r.kv("Object.class.getSuperclass()", Object.class.getSuperclass());

        r.heading("5. Type tests and casts through Class objects");
        r.kv("Candidate.class.isAssignableFrom(Special.class)", Candidate.class.isAssignableFrom(Special.class));
        r.kv("Special.class.isAssignableFrom(Candidate.class)", Special.class.isAssignableFrom(Candidate.class));
        r.kv("Special.class.isInstance(c)", Special.class.isInstance(c));
        Special s = Special.class.cast(c);                  // the reflective form of (Special) c
        r.kv("Special.class.cast(c).getX()", s.getX());
        try {
            Variant.A.class.cast(c);
        } catch (ClassCastException e) {
            r.kv("Variant.A.class.cast(c)", "ClassCastException");
        }
        r.note("isAssignableFrom and isInstance are what a container uses to find 'all components that implement X'.");

        r.heading("6. Pattern matching: the compiler uses RTTI too");
        for (Variant v : List.of(new Variant.A(1, "one"), new Variant.B(2.5))) {
            String text = switch (v) {                       // no default branch needed: Variant is sealed
                case Variant.A a -> "A with value " + a.value() + " and tag " + a.tag();
                case Variant.B b -> "B with weight " + b.weight();
            };
            r.kv("switch (v) for a " + v.getClass().getSimpleName(), text);
        }
        r.note("instanceof and switch patterns are compiled to type checks against the object's class.");

        r.heading("7. Sealed types, records and enums describe themselves");
        r.kv("Variant.class.isSealed()", Variant.class.isSealed());
        r.kv("Variant.class.getPermittedSubclasses()", Arrays.stream(Variant.class.getPermittedSubclasses()).map(Class::getSimpleName).toList());
        r.kv("Variant.A.class.isRecord()", Variant.A.class.isRecord());
        r.kv("Variant.A.class.getRecordComponents()", components(Variant.A.class));
        r.kv("Variant.B.class.isRecord()", Variant.B.class.isRecord());
        r.kv("Variant.Mode.class.isEnum()", Variant.Mode.class.isEnum());
        r.kv("Variant.Mode.class.getEnumConstants()", Arrays.toString(Variant.Mode.class.getEnumConstants()));
        r.note("Record components are the reason records are so convenient for generic serializers (stage 02).");

        r.heading("8. Generics are erased from objects, but declarations keep their signatures");
        r.kv("new ArrayList<String>().getClass() == new ArrayList<Integer>().getClass()",
                new ArrayList<String>().getClass() == new ArrayList<Integer>().getClass());
        Field items = Holder.class.getDeclaredField("items");
        Field index = Holder.class.getDeclaredField("index");
        r.kv("field items: getType()", items.getType().getSimpleName());
        r.kv("field items: getGenericType()", items.getGenericType());
        r.kv("field index: getType()", index.getType().getSimpleName());
        r.kv("field index: getGenericType()", index.getGenericType());
        TypeRef<List<String>> ref = new TypeRef<>() {};
        r.kv("new TypeRef<List<String>>() {}.type()", ref.type());
        r.note("The ArrayList object does not know it is a List<String>; the field declaration and the anonymous "
                + "subclass declaration do. Jackson's TypeReference uses this trick.");

        r.heading("9. Lambdas and anonymous classes have classes too");
        Runnable lambda = () -> {};
        Runnable anonymous = new Runnable() {
            @Override
            public void run() {}
        };
        r.kv("lambda.getClass().getName()", lambda.getClass().getName());
        r.kv("lambda.getClass().isHidden()", lambda.getClass().isHidden());
        r.kv("anonymous.getClass().getName()", anonymous.getClass().getName());
        r.kv("anonymous.getClass().isAnonymousClass()", anonymous.getClass().isAnonymousClass());
        r.note("Lambda classes are generated at run time and are 'hidden': Class.forName() cannot find them. "
                + "Stage 07 generates classes the same way.");
        r.flush();
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
}
