package sa4e.reflect;

import java.io.PrintStream;
import java.io.StringWriter;
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
import javax.xml.stream.XMLOutputFactory;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamWriter;

/**
 * Produces an XML description of any class: constructors, fields and methods with their
 * modifiers, types and parameters. This is the "TalkAbout" example from the lecture slides.
 * <p>
 * Stage 03: annotations are included. The Inspector does not know any annotation type; it
 * reads whatever is present and lists the annotation's members by calling them reflectively.
 * Classes, constructors, fields, methods and parameters all implement {@link AnnotatedElement},
 * so one method handles them all.
 * <p>
 * The XML is written element by element with the JDK's StAX writer ({@link XMLStreamWriter},
 * module {@code java.xml}). The writer escapes attribute values and text and keeps track of the
 * open elements, so the document is well-formed by construction; the Inspector only says which
 * element and which attribute comes next. The line breaks and indentation between elements are
 * insignificant whitespace, added by three small helpers so that the output stays readable.
 */
public final class Inspector {

    private final Class<?> target;
    private int depth;                                   // nesting of the element being written

    public Inspector(Class<?> target) {
        this.target = target;
    }

    public void print(PrintStream out) {
        out.println(describe());
    }

    public String describe() {
        StringWriter text = new StringWriter();
        depth = 0;
        try {
            XMLStreamWriter xml = XMLOutputFactory.newDefaultFactory().createXMLStreamWriter(text);
            xml.writeStartDocument("UTF-8", "1.0");
            startElement(xml, "class");
            xml.writeAttribute("name", target.getName());
            xml.writeAttribute("modifiers", Modifier.toString(target.getModifiers()));
            xml.writeAttribute("superclass", target.getSuperclass() == null ? "" : target.getSuperclass().getName());
            writeAnnotations(xml, target);

            // The reflection API makes no promise about the order of members, so sort for stable output.
            Constructor<?>[] constructors = target.getDeclaredConstructors();
            Arrays.sort(constructors, Comparator.comparing(Constructor::toGenericString));
            for (Constructor<?> ctor : constructors) {
                startElement(xml, "constructor");
                xml.writeAttribute("modifiers", Modifier.toString(ctor.getModifiers()));
                writeAnnotations(xml, ctor);
                writeParameters(xml, ctor);
                endElement(xml);
            }

            Field[] fields = target.getDeclaredFields();
            Arrays.sort(fields, Comparator.comparing(Field::getName));
            for (Field f : fields) {
                boolean annotated = f.getAnnotations().length > 0;   // self-closing unless there is something inside
                if (annotated) startElement(xml, "field"); else emptyElement(xml, "field");
                xml.writeAttribute("name", f.getName());
                xml.writeAttribute("type", f.getType().getName());
                xml.writeAttribute("modifiers", Modifier.toString(f.getModifiers()));
                writeAnnotations(xml, f);
                if (annotated) endElement(xml);
            }

            Method[] methods = target.getDeclaredMethods();
            Arrays.sort(methods, Comparator.comparing(Method::getName).thenComparing(Method::toGenericString));
            for (Method m : methods) {
                if (m.isSynthetic()) continue;               // compiler-generated helpers (lambdas, bridges)
                startElement(xml, "method");
                xml.writeAttribute("name", m.getName());
                xml.writeAttribute("modifiers", Modifier.toString(m.getModifiers()));
                xml.writeAttribute("returns", m.getReturnType().getName());
                writeAnnotations(xml, m);
                writeParameters(xml, m);
                endElement(xml);
            }
            endElement(xml);                                 // </class>
            xml.writeEndDocument();
            xml.close();
        } catch (XMLStreamException e) {
            throw new IllegalStateException("cannot write XML", e);   // not expected with a StringWriter
        }
        return text.toString();
    }

    /** Constructors and methods share the type {@link Executable}, so parameters are handled once. */
    private void writeParameters(XMLStreamWriter xml, Executable executable) throws XMLStreamException {
        for (Parameter p : executable.getParameters()) {
            // p.getName() is only meaningful if the class was compiled with -parameters;
            // otherwise the compiler stores nothing and reflection makes up "arg0", "arg1", ...
            boolean annotated = p.getAnnotations().length > 0;
            if (annotated) startElement(xml, "parameter"); else emptyElement(xml, "parameter");
            xml.writeAttribute("name", p.getName());
            xml.writeAttribute("type", p.getType().getName());
            writeAnnotations(xml, p);
            if (annotated) endElement(xml);
        }
    }

    /**
     * Lists all run-time visible annotations of an element without knowing their types.
     * An annotation's members are methods of its annotation type, so they can be found and
     * called like any other method.
     */
    private void writeAnnotations(XMLStreamWriter xml, AnnotatedElement element) throws XMLStreamException {
        for (Annotation a : element.getAnnotations()) {
            Class<? extends Annotation> type = a.annotationType();
            Method[] members = type.getDeclaredMethods();
            Arrays.sort(members, Comparator.comparing(Method::getName));
            if (members.length == 0) {
                emptyElement(xml, "annotation");
                xml.writeAttribute("type", type.getName());
                continue;
            }
            startElement(xml, "annotation");
            xml.writeAttribute("type", type.getName());
            for (Method member : members) {
                newLine(xml);
                xml.writeStartElement("member");       // text inside, so no depth change
                xml.writeAttribute("name", member.getName());
                xml.writeCharacters(String.valueOf(memberValue(a, member)));   // the writer escapes <, > and &
                xml.writeEndElement();
            }
            endElement(xml);
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

    // The three writer calls, each on a new line and indented by the nesting depth.

    private void startElement(XMLStreamWriter xml, String name) throws XMLStreamException {
        newLine(xml);
        xml.writeStartElement(name);
        depth++;
    }

    private void emptyElement(XMLStreamWriter xml, String name) throws XMLStreamException {
        newLine(xml);
        xml.writeEmptyElement(name);
    }

    private void endElement(XMLStreamWriter xml) throws XMLStreamException {
        depth--;
        newLine(xml);
        xml.writeEndElement();
    }

    private void newLine(XMLStreamWriter xml) throws XMLStreamException {
        xml.writeCharacters("\n" + "  ".repeat(depth));
    }
}
