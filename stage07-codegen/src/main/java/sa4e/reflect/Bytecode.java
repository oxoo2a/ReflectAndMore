package sa4e.reflect;

import java.lang.classfile.ClassFile;
import java.lang.classfile.ClassModel;
import java.lang.classfile.CodeElement;
import java.lang.classfile.CodeModel;
import java.lang.classfile.Instruction;
import java.lang.classfile.MethodModel;
import java.lang.classfile.instruction.ConstantInstruction;
import java.lang.classfile.instruction.FieldInstruction;
import java.lang.classfile.instruction.InvokeInstruction;
import java.lang.classfile.instruction.LoadInstruction;
import java.lang.classfile.instruction.StoreInstruction;
import java.util.ArrayList;
import java.util.List;

/**
 * Reads class files with the ClassFile API ({@code java.lang.classfile}, standard since
 * Java 24) and lists methods and instructions, a little like {@code javap -c}.
 */
public final class Bytecode {

    private Bytecode() {}

    public static ClassModel parse(byte[] bytes) {
        return ClassFile.of().parse(bytes);
    }

    /** Method name, descriptor and code size of every method. */
    public static List<String> methods(ClassModel model) {
        List<String> result = new ArrayList<>();
        for (MethodModel m : model.methods()) {
            int instructions = m.code().map(c -> (int) c.elementStream().filter(e -> e instanceof Instruction).count()).orElse(0);
            result.add(m.methodName().stringValue() + m.methodTypeSymbol().displayDescriptor() + " : " + instructions + " instructions");
        }
        return result;
    }

    /** The instructions of one method, one per line. */
    public static String instructions(ClassModel model, String methodName) {
        StringBuilder sb = new StringBuilder();
        for (MethodModel m : model.methods()) {
            if (!m.methodName().stringValue().equals(methodName)) continue;
            CodeModel code = m.code().orElseThrow();
            for (CodeElement element : code) {
                if (element instanceof Instruction i) sb.append(describe(i)).append('\n');
            }
        }
        return sb.toString();
    }

    private static String describe(Instruction i) {
        String opcode = i.opcode().name().toLowerCase();
        return switch (i) {
            case InvokeInstruction inv -> opcode + " " + inv.owner().asInternalName() + "." + inv.name().stringValue() + inv.typeSymbol().displayDescriptor();
            case FieldInstruction f -> opcode + " " + f.owner().asInternalName() + "." + f.name().stringValue() + " : " + f.typeSymbol().displayName();
            case LoadInstruction l -> opcode.matches(".*_\\d") ? opcode : opcode + " " + l.slot();
            case StoreInstruction s -> opcode.matches(".*_\\d") ? opcode : opcode + " " + s.slot();
            case ConstantInstruction c -> opcode + " " + c.constantValue();
            default -> opcode;
        };
    }
}
