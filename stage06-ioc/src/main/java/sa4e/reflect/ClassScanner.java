package sa4e.reflect;

import java.io.File;
import java.io.IOException;
import java.net.JarURLConnection;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Enumeration;
import java.util.List;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import java.util.stream.Stream;

/**
 * Finds every class below a package, whether the classes sit in a directory or in a jar.
 * The JDK has no API for this, so every container writes its own: this is "classpath
 * scanning", the first thing Spring does at startup.
 */
public final class ClassScanner {

    private ClassScanner() {}

    public static List<Class<?>> scan(String basePackage, ClassLoader loader) throws IOException {
        String path = basePackage.replace('.', '/');
        List<String> names = new ArrayList<>();
        Enumeration<URL> roots = loader.getResources(path);          // every class path entry that has the package
        while (roots.hasMoreElements()) {
            URL root = roots.nextElement();
            switch (root.getProtocol()) {
                case "file" -> scanDirectory(toPath(root), basePackage, names);
                case "jar" -> scanJar(root, path, names);
                default -> { /* not needed here */ }
            }
        }
        List<Class<?>> classes = new ArrayList<>();
        for (String name : names) {
            try {
                classes.add(Class.forName(name, false, loader));         // false: do not initialize while scanning
            } catch (ClassNotFoundException | LinkageError e) {
                // skip what cannot be loaded
            }
        }
        classes.sort(Comparator.comparing(Class::getName));
        return classes;
    }

    private static Path toPath(URL url) throws IOException {
        try {
            return Path.of(url.toURI());
        } catch (URISyntaxException e) {
            throw new IOException(e);
        }
    }

    private static void scanDirectory(Path root, String basePackage, List<String> names) throws IOException {
        try (Stream<Path> files = Files.walk(root)) {
            files.filter(p -> p.toString().endsWith(".class")).forEach(p -> {
                String relative = root.relativize(p).toString().replace(File.separatorChar, '.');
                names.add(basePackage + "." + relative.substring(0, relative.length() - ".class".length()));
            });
        }
    }

    private static void scanJar(URL url, String path, List<String> names) throws IOException {
        JarURLConnection connection = (JarURLConnection) url.openConnection();
        try (JarFile jar = new JarFile(new File(toPath(connection.getJarFileURL()).toString()))) {
            Enumeration<JarEntry> entries = jar.entries();
            while (entries.hasMoreElements()) {
                String entry = entries.nextElement().getName();
                if (entry.startsWith(path + "/") && entry.endsWith(".class")) {
                    names.add(entry.substring(0, entry.length() - ".class".length()).replace('/', '.'));
                }
            }
        }
    }
}
