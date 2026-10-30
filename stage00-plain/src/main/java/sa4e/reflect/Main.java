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
        Report r = Report.stdout();
        r.title("Stage 00: plain Java");

        Candidate a = new Candidate(7);
        Candidate b = new Candidate();
        a.f(3, -1.0);

        r.heading("Using Candidate the ordinary way");
        r.kv("a = new Candidate(7); a.f(3, -1.0)", a);
        r.kv("b = new Candidate()", b);
        r.kv("Candidate.created()", Candidate.created());

        r.heading("What this program cannot do");
        r.item("describe Candidate (its fields, constructors, methods) without reading its source code");
        r.item("call secret() or the private constructor");
        r.item("create an instance of a class whose name becomes known only while the program runs");
        r.item("decorate, replace or wire Candidate without editing Main");
        r.note("Every call in this program was resolved when javac ran. The following stages remove these limits one by one.");
        r.flush();
    }
}
