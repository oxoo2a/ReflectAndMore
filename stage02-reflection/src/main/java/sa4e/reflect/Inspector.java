package sa4e.reflect;

import java.io.PrintStream;
import java.lang.reflect.Constructor;
import java.lang.reflect.Executable;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.lang.reflect.Parameter;
import java.util.Arrays;
import java.util.Comparator;

/**
 * Produces an XML description of any class: constructors, fields and methods with their
 * modifiers, types and parameters. The class is never instantiated and does not need to be
 * known at compile time. This is the "TalkAbout" example from the lecture slides.
 * <p>
 * Everything comes from {@link Class}: {@code getDeclaredConstructors()},
 * {@code getDeclaredFields()} and {@code getDeclaredMethods()} return all members declared in
 * the class itself, regardless of visibility. Their {@code get...()} counterparts without
 * "Declared" return only public members, but including inherited ones.
 */
public final class Inspector {

    private final Class<?> target;

    public Inspector(Class<?> target) {
        this.target = target;
    }

    public void print(PrintStream out) {
        out.print(describe());
    }

    public String describe() {
        StringBuilder xml = new StringBuilder();
        xml.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        xml.append("<class name=\"").append(target.getName())
           .append("\" modifiers=\"").append(Modifier.toString(target.getModifiers()))
           .append("\" superclass=\"").append(target.getSuperclass() == null ? "" : target.getSuperclass().getName())
           .append("\">\n");

        // The reflection API makes no promise about the order of members, so sort for stable output.
        Constructor<?>[] constructors = target.getDeclaredConstructors();
        Arrays.sort(constructors, Comparator.comparing(Constructor::toGenericString));
        for (Constructor<?> ctor : constructors) {
            xml.append("  <constructor modifiers=\"").append(Modifier.toString(ctor.getModifiers())).append("\">\n");
            appendParameters(xml, ctor);
            xml.append("  </constructor>\n");
        }

        Field[] fields = target.getDeclaredFields();
        Arrays.sort(fields, Comparator.comparing(Field::getName));
        for (Field f : fields) {
            xml.append("  <field name=\"").append(f.getName())
               .append("\" type=\"").append(f.getType().getName())
               .append("\" modifiers=\"").append(Modifier.toString(f.getModifiers())).append("\"/>\n");
        }

        Method[] methods = target.getDeclaredMethods();
        Arrays.sort(methods, Comparator.comparing(Method::getName).thenComparing(Method::toGenericString));
        for (Method m : methods) {
            if (m.isSynthetic()) continue;               // compiler-generated helpers (lambdas, bridges)
            xml.append("  <method name=\"").append(m.getName())
               .append("\" modifiers=\"").append(Modifier.toString(m.getModifiers()))
               .append("\" returns=\"").append(m.getReturnType().getName()).append("\">\n");
            appendParameters(xml, m);
            xml.append("  </method>\n");
        }
        xml.append("</class>\n");
        return xml.toString();
    }

    /** Constructors and methods share the type {@link Executable}, so parameters are handled once. */
    private static void appendParameters(StringBuilder xml, Executable executable) {
        for (Parameter p : executable.getParameters()) {
            // p.getName() is only meaningful if the class was compiled with -parameters;
            // otherwise the compiler stores nothing and reflection makes up "arg0", "arg1", ...
            xml.append("    <parameter name=\"").append(p.getName())
               .append("\" type=\"").append(p.getType().getName()).append("\"/>\n");
        }
    }
}
