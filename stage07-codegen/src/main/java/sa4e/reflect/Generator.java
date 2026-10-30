package sa4e.reflect;

import java.lang.classfile.Annotation;
import java.lang.classfile.AnnotationElement;
import java.lang.classfile.ClassFile;
import java.lang.classfile.attribute.RuntimeVisibleAnnotationsAttribute;
import java.lang.constant.ClassDesc;
import java.lang.constant.MethodTypeDesc;

import static java.lang.constant.ConstantDescs.CD_Object;
import static java.lang.constant.ConstantDescs.CD_String;
import static java.lang.constant.ConstantDescs.CD_double;
import static java.lang.constant.ConstantDescs.CD_int;
import static java.lang.constant.ConstantDescs.CD_void;
import static java.lang.constant.ConstantDescs.INIT_NAME;
import static java.lang.constant.ConstantDescs.MTD_void;

/**
 * Writes class files with the ClassFile API. No source code, no compiler: the bytes are
 * assembled instruction by instruction and can be defined as a class immediately.
 */
public final class Generator {

    private static final ClassDesc CAPABILITY = ClassDesc.of("sa4e.reflect.Capability");
    private static final ClassDesc CANDIDATE = ClassDesc.of("sa4e.reflect.Candidate");
    private static final ClassDesc INTERCEPTOR = ClassDesc.of("sa4e.reflect.Interceptor");
    private static final ClassDesc COMMENT = ClassDesc.of("sa4e.reflect.Comment");
    private static final ClassDesc STRING_BUILDER = ClassDesc.of("java.lang.StringBuilder");
    private static final MethodTypeDesc F_TYPE = MethodTypeDesc.of(CD_void, CD_int, CD_double);
    private static final MethodTypeDesc GET_X_TYPE = MethodTypeDesc.of(CD_int);

    private Generator() {}

    /**
     * A complete implementation of Capability from nothing, equivalent to
     * <pre>
     * {@literal @}Comment("generated at run time")
     * public final class Generated implements Capability {
     *     private int x;
     *     public int getX() { return x; }
     *     public void f(int y, double d) { x = y; }
     *     public String toString() { return "Generated{x=" + x + "}"; }
     * }
     * </pre>
     */
    public static byte[] implementation(String className) {
        ClassDesc self = ClassDesc.of(className);
        return ClassFile.of().build(self, cb -> {
            cb.withFlags(ClassFile.ACC_PUBLIC | ClassFile.ACC_FINAL);
            cb.withSuperclass(CD_Object);
            cb.withInterfaceSymbols(CAPABILITY);
            cb.with(RuntimeVisibleAnnotationsAttribute.of(
                    Annotation.of(COMMENT, AnnotationElement.ofString("value", "generated at run time"))));
            cb.withField("x", CD_int, ClassFile.ACC_PRIVATE);

            cb.withMethodBody(INIT_NAME, MTD_void, ClassFile.ACC_PUBLIC, code -> code
                    .aload(0)
                    .invokespecial(CD_Object, INIT_NAME, MTD_void)      // super();
                    .return_());

            cb.withMethodBody("getX", GET_X_TYPE, ClassFile.ACC_PUBLIC, code -> code
                    .aload(0)
                    .getfield(self, "x", CD_int)                        // this.x
                    .ireturn());

            cb.withMethodBody("f", F_TYPE, ClassFile.ACC_PUBLIC, code -> code
                    .aload(0)
                    .iload(1)                                           // y (slot 1; d occupies slots 2 and 3)
                    .putfield(self, "x", CD_int)                        // this.x = y
                    .return_());

            cb.withMethodBody("toString", MethodTypeDesc.of(CD_String), ClassFile.ACC_PUBLIC, code -> code
                    .new_(STRING_BUILDER)
                    .dup()
                    .invokespecial(STRING_BUILDER, INIT_NAME, MTD_void)
                    .ldc("Generated{x=")
                    .invokevirtual(STRING_BUILDER, "append", MethodTypeDesc.of(STRING_BUILDER, CD_String))
                    .aload(0)
                    .getfield(self, "x", CD_int)
                    .invokevirtual(STRING_BUILDER, "append", MethodTypeDesc.of(STRING_BUILDER, CD_int))
                    .ldc("}")
                    .invokevirtual(STRING_BUILDER, "append", MethodTypeDesc.of(STRING_BUILDER, CD_String))
                    .invokevirtual(STRING_BUILDER, "toString", MethodTypeDesc.of(CD_String))
                    .areturn());
        });
    }

    /**
     * A subclass of Candidate that reports every call of getX and f to Interceptor before
     * delegating to the original method, equivalent to
     * <pre>
     * public class Candidate$$Intercepted extends Candidate {
     *     public Candidate$$Intercepted(int x) { super(x); }
     *     public int getX() { Interceptor.before("getX"); return super.getX(); }
     *     public void f(int y, double d) { Interceptor.before("f"); super.f(y, d); }
     * }
     * </pre>
     * This is what stage 04 could not do: a proxy for a class instead of an interface.
     */
    public static byte[] interceptingSubclass(String className) {
        ClassDesc self = ClassDesc.of(className);
        MethodTypeDesc before = MethodTypeDesc.of(CD_void, CD_String);
        return ClassFile.of().build(self, cb -> {
            cb.withFlags(ClassFile.ACC_PUBLIC);
            cb.withSuperclass(CANDIDATE);

            cb.withMethodBody(INIT_NAME, MethodTypeDesc.of(CD_void, CD_int), ClassFile.ACC_PUBLIC, code -> code
                    .aload(0)
                    .iload(1)
                    .invokespecial(CANDIDATE, INIT_NAME, MethodTypeDesc.of(CD_void, CD_int))   // super(x);
                    .return_());

            cb.withMethodBody("getX", GET_X_TYPE, ClassFile.ACC_PUBLIC, code -> code
                    .ldc("getX")
                    .invokestatic(INTERCEPTOR, "before", before)
                    .aload(0)
                    .invokespecial(CANDIDATE, "getX", GET_X_TYPE)       // super.getX()
                    .ireturn());

            cb.withMethodBody("f", F_TYPE, ClassFile.ACC_PUBLIC, code -> code
                    .ldc("f")
                    .invokestatic(INTERCEPTOR, "before", before)
                    .aload(0)
                    .iload(1)
                    .dload(2)
                    .invokespecial(CANDIDATE, "f", F_TYPE)              // super.f(y, d)
                    .return_());
        });
    }
}
