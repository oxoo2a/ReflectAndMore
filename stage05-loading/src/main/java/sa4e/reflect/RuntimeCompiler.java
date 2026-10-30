package sa4e.reflect;

import javax.tools.JavaCompiler;
import javax.tools.ToolProvider;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Compiles Java source code while the program runs, using the compiler that ships with every
 * JDK ({@code javax.tools}). Application servers, JSP engines and scripting bridges do this.
 */
public final class RuntimeCompiler {

    private RuntimeCompiler() {}

    /** Compiles one class and returns the directory containing the class file. */
    public static Path compile(String className, String source, Path outputDir) throws IOException {
        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
        if (compiler == null) {
            throw new IllegalStateException("no compiler available: a JRE is not enough, a JDK is needed");
        }
        Files.createDirectories(outputDir);
        Path sourceFile = outputDir.resolve(className + ".java");
        Files.writeString(sourceFile, source);

        ByteArrayOutputStream errors = new ByteArrayOutputStream();
        int status = compiler.run(null, null, errors,
                "-classpath", System.getProperty("java.class.path"),   // so that sa4e.reflect.Capability resolves
                "-d", outputDir.toString(),
                sourceFile.toString());
        if (status != 0) {
            throw new IllegalStateException("compilation failed:\n" + errors.toString(StandardCharsets.UTF_8));
        }
        return outputDir;
    }
}
