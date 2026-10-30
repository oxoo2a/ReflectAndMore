package sa4e.reflect;

/**
 * The class under investigation.
 * <p>
 * It is deliberately boring and has no meaning: it only exists so that there are constructors,
 * fields and methods of every visibility to look at. In later stages the framework code around
 * it grows; Candidate itself changes as little as possible.
 * <p>
 * Stage 03 added a few annotations. Stage 04 makes Candidate implement {@link Capability}, so
 * that proxies can stand in for it, and marks {@code f} as {@link Transactional}.
 */
@Comment("the class under investigation")
@Marker
public class Candidate implements Capability {

    private static int created;        // counts instances, a static field to look at later

    @Range(min = -100, max = 100)
    private int x;

    @NotNull
    private final String label;

    public Candidate(int x) {
        this.x = x;
        this.label = "candidate#" + x;
        created++;
    }

    public Candidate() {
        this(0);
        reset();
    }

    /** Only reachable from inside the class. Stage 02 will call it anyway. */
    private Candidate(String label) {
        this.x = -1;
        this.label = label;
        created++;
    }

    @Override
    @Comment("reads x")
    public int getX() {
        return x;
    }

    @Override
    @Transactional
    public void f(@Range(min = -10, max = 10) int y, double d) {
        if (d < 0) x = y; else x = -y;
    }

    protected void reset() {
        x = 42;
    }

    private String secret() {
        return "the secret of " + label;
    }

    public static int created() {
        return created;
    }

    /** Hand-written description: must be edited whenever a field is added, renamed or removed. */
    @Override
    public String toString() {
        return "Candidate{x=" + x + ", label='" + label + "'}";
    }
}
