package sa4e.reflect;

/**
 * Stage 00: plain Java, no meta-programming at all.
 * <p>
 * Everything Main knows about Candidate it knows at compile time, because the compiler read
 * Candidate.java. Nothing can be learned about Candidate at run time, nothing private can be
 * reached, and no class can be used whose name is not written down in the source code.
 */
public final class Main {

    public static void main(String[] args) {
        System.out.println("Java " + Runtime.version() + ", " + System.getProperty("java.vm.name")
                + " (" + System.getProperty("java.vendor") + "), " + System.getProperty("java.home"));
        System.out.println();
        Candidate a = new Candidate(7);
        Candidate b = new Candidate();
        a.f(3, -1.0);

        System.out.println(a);
        System.out.println(b);
        System.out.println("instances created: " + Candidate.created());

        // Things this program cannot do (yet):
        //   - describe Candidate (its fields, constructors, methods) without reading its source code
        //   - call secret() or the private constructor
        //   - create an instance of a class whose name becomes known only while the program runs
        //   - decorate, replace or wire Candidate without editing Main
    }
}
