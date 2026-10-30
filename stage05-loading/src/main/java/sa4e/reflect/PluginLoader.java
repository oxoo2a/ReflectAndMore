package sa4e.reflect;

import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Path;

/**
 * Loads classes from a directory with a fresh class loader. The new loader's parent is the
 * loader of this class, so everything the plugin shares with the application (for example
 * the Capability interface) is resolved by the parent and is therefore the same Class object
 * on both sides. Only the plugin's own classes are defined by the new loader.
 */
public final class PluginLoader {

    private PluginLoader() {}

    public static Class<?> load(Path classesDir, String className) throws Exception {
        URL[] urls = {classesDir.toUri().toURL()};
        // Not closed on purpose: the loader must stay alive as long as its classes are in use.
        URLClassLoader loader = new URLClassLoader("plugin:" + classesDir.getFileName(), urls, PluginLoader.class.getClassLoader());
        return loader.loadClass(className);
    }
}
