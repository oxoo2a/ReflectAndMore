package sa4e.reflect;

import java.lang.reflect.ParameterizedType;
import java.lang.reflect.Type;

/**
 * The "super type token" trick.
 * <p>
 * Generic type arguments are erased from objects, but the generic signature of a class
 * declaration survives in the class file. Writing {@code new TypeRef<List<String>>() {}} creates
 * an anonymous subclass whose declared superclass is {@code TypeRef<List<String>>}, and that
 * declaration can be read back. Jackson's {@code TypeReference} and Guice's {@code TypeLiteral}
 * work exactly like this.
 */
public abstract class TypeRef<T> {
    private final Type type;

    protected TypeRef() {
        Type superclass = getClass().getGenericSuperclass();
        if (!(superclass instanceof ParameterizedType parameterized)) {
            throw new IllegalStateException("use: new TypeRef<SomeType>() {}");
        }
        this.type = parameterized.getActualTypeArguments()[0];
    }

    public Type type() {
        return type;
    }
}
