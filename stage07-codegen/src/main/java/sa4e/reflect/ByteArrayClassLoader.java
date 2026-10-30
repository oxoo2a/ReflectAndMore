package sa4e.reflect;

/**
 * Turns bytes into a class. {@code defineClass} is protected in {@link ClassLoader}, so a tiny
 * subclass is needed. The parent is the application loader, so generated classes can refer to
 * Candidate, Capability and the JDK.
 */
public final class ByteArrayClassLoader extends ClassLoader {

    public ByteArrayClassLoader() {
        super("generated", ByteArrayClassLoader.class.getClassLoader());
    }

    public Class<?> define(String name, byte[] bytes) {
        return defineClass(name, bytes, 0, bytes.length);
    }
}
