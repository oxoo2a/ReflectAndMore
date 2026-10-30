package sa4e.reflect;

import java.io.PrintStream;
import java.lang.annotation.Annotation;
import java.lang.reflect.AnnotatedElement;
import java.lang.reflect.Constructor;
import java.lang.reflect.Executable;
import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.lang.reflect.Parameter;
import java.util.Arrays;
import java.util.Comparator;

/**
 * Produces an XML description of any class: constructors, fields and methods with their
 * modifiers, types and parameters. This is the "TalkAbout" example from the lecture slides.
 * <p>
 * Stage 03: annotations are included. The Inspector does not know any annotation type; it
 * reads whatever is present and lists the annotation's members by calling them reflectively.
 * Classes, constructors, fields, methods and parameters all implement {@link AnnotatedElement},
 * so one method handles them all.
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
        appendAnnotations(xml, target, "  ");

        // The reflection API makes no promise about the order of members, so sort for stable output.
        Constructor<?>[] constructors = target.getDeclaredConstructors();
        Arrays.sort(constructors, Comparator.comparing(Constructor::toGenericString));
        for (Constructor<?> ctor : constructors) {
            xml.append("  <constructor modifiers=\"").append(Modifier.toString(ctor.getModifiers())).append("\">\n");
            appendAnnotations(xml, ctor, "    ");
            appendParameters(xml, ctor);
            xml.append("  </constructor>\n");
        }

        Field[] fields = target.getDeclaredFields();
        Arrays.sort(fields, Comparator.comparing(Field::getName));
        for (Field f : fields) {
            xml.append("  <field name=\"").append(f.getName())
               .append("\" type=\"").append(f.getType().getName())
               .append("\" modifiers=\"").append(Modifier.toString(f.getModifiers())).append("\"");
            closeWithAnnotations(xml, f, "  ", "field");
        }

        Method[] methods = target.getDeclaredMethods();
        Arrays.sort(methods, Comparator.comparing(Method::getName).thenComparing(Method::toGenericString));
        for (Method m : methods) {
            if (m.isSynthetic()) continue;               // compiler-generated helpers (lambdas, bridges)
            xml.append("  <method name=\"").append(m.getName())
               .append("\" modifiers=\"").append(Modifier.toString(m.getModifiers()))
               .append("\" returns=\"").append(m.getReturnType().getName()).append("\">\n");
            appendAnnotations(xml, m, "    ");
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
               .append("\" type=\"").append(p.getType().getName()).append("\"");
            closeWithAnnotations(xml, p, "    ", "parameter");
        }
    }

    /** Closes an element: self-closing if it has no annotations, otherwise with the annotations inside. */
    private static void closeWithAnnotations(StringBuilder xml, AnnotatedElement element, String indent, String tag) {
        StringBuilder inner = new StringBuilder();
        appendAnnotations(inner, element, indent + "  ");
        if (inner.isEmpty()) {
            xml.append("/>\n");
        } else {
            xml.append(">\n").append(inner).append(indent).append("</").append(tag).append(">\n");
        }
    }

    /**
     * Lists all run-time visible annotations of an element without knowing their types.
     * An annotation's members are methods of its annotation type, so they can be found and
     * called like any other method.
     */
    private static void appendAnnotations(StringBuilder xml, AnnotatedElement element, String indent) {
        for (Annotation a : element.getAnnotations()) {
            Class<? extends Annotation> type = a.annotationType();
            Method[] members = type.getDeclaredMethods();
            Arrays.sort(members, Comparator.comparing(Method::getName));
            xml.append(indent).append("<annotation type=\"").append(type.getName()).append("\"");
            if (members.length == 0) {
                xml.append("/>\n");
                continue;
            }
            xml.append(">\n");
            for (Method member : members) {
                xml.append(indent).append("  <member name=\"").append(member.getName()).append("\">")
                   .append(escape(memberValue(a, member))).append("</member>\n");
            }
            xml.append(indent).append("</annotation>\n");
        }
    }

    private static Object memberValue(Annotation a, Method member) {
        try {
            Object value = member.invoke(a);
            return value.getClass().isArray() ? Arrays.deepToString((Object[]) value) : value;
        } catch (IllegalAccessException | InvocationTargetException e) {
            return "?";
        }
    }

    private static String escape(Object value) {
        return String.valueOf(value).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }
}
