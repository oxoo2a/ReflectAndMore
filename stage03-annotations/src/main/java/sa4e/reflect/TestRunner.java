package sa4e.reflect;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;

/**
 * A test framework in 40 lines. The runner decides what to create and when to call what; the
 * test class only declares, through annotations, which methods matter. This reversal of who
 * calls whom is "inversion of control", which stage 06 turns into a container.
 */
public final class TestRunner {

    public record Result(String test, String outcome, String detail) {}

    private TestRunner() {}

    public static List<Result> run(Class<?> testClass) throws ReflectiveOperationException {
        Method[] methods = testClass.getDeclaredMethods();
        Arrays.sort(methods, Comparator.comparing(Method::getName));   // reflection promises no order
        List<Method> setups = new ArrayList<>();
        List<Method> tests = new ArrayList<>();
        for (Method m : methods) {
            m.setAccessible(true);                                     // test methods are usually package-private
            if (m.isAnnotationPresent(BeforeEach.class)) setups.add(m);
            if (m.isAnnotationPresent(Test.class)) tests.add(m);
        }

        List<Result> results = new ArrayList<>();
        for (Method test : tests) {
            Disabled disabled = test.getAnnotation(Disabled.class);
            if (disabled != null) {
                results.add(new Result(test.getName(), "skipped", disabled.value()));
                continue;
            }
            Object instance = testClass.getDeclaredConstructor().newInstance();   // fresh instance per test
            try {
                for (Method setup : setups) setup.invoke(instance);
                test.invoke(instance);
                results.add(new Result(test.getName(), "passed", ""));
            } catch (InvocationTargetException e) {                    // the test threw: unwrap the real cause
                Throwable cause = e.getCause();
                results.add(new Result(test.getName(), "failed", cause.getClass().getSimpleName() + ": " + cause.getMessage()));
            }
        }
        return results;
    }
}
