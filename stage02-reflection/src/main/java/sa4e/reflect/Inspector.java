package sa4e.reflect;

import java.io.PrintStream;
import java.io.StringWriter;
import java.lang.reflect.Constructor;
import java.lang.reflect.Executable;
import java.lang.reflect.Field;
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
 * modifiers, types and parameters. The class is never instantiated and does not need to be
 * known at compile time. This is the "TalkAbout" example from the lecture slides.
 * <p>
 * Everything comes from {@link Class}: {@code getDeclaredConstructors()},
 * {@code getDeclaredFields()} and {@code getDeclaredMethods()} return all members declared in
 * the class itself, regardless of visibility. Their {@code get...()} counterparts without
 * "Declared" return only public members, but including inherited ones.
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

            // The reflection API makes no promise about the order of members, so sort for stable output.
            Constructor<?>[] constructors = target.getDeclaredConstructors();
            Arrays.sort(constructors, Comparator.comparing(Constructor::toGenericString));
            for (Constructor<?> ctor : constructors) {
                startElement(xml, "constructor");
                xml.writeAttribute("modifiers", Modifier.toString(ctor.getModifiers()));
                writeParameters(xml, ctor);
                endElement(xml);
            }

            Field[] fields = target.getDeclaredFields();
            Arrays.sort(fields, Comparator.comparing(Field::getName));
            for (Field f : fields) {
                emptyElement(xml, "field");
                xml.writeAttribute("name", f.getName());
                xml.writeAttribute("type", f.getType().getName());
                xml.writeAttribute("modifiers", Modifier.toString(f.getModifiers()));
            }

            Method[] methods = target.getDeclaredMethods();
            Arrays.sort(methods, Comparator.comparing(Method::getName).thenComparing(Method::toGenericString));
            for (Method m : methods) {
                if (m.isSynthetic()) continue;               // compiler-generated helpers (lambdas, bridges)
                startElement(xml, "method");
                xml.writeAttribute("name", m.getName());
                xml.writeAttribute("modifiers", Modifier.toString(m.getModifiers()));
                xml.writeAttribute("returns", m.getReturnType().getName());
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
            emptyElement(xml, "parameter");
            xml.writeAttribute("name", p.getName());
            xml.writeAttribute("type", p.getType().getName());
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
