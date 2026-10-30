package sa4e.reflect;

/** Tests for Candidate, written against our own annotations. One test fails on purpose. */
public class CandidateTests {

    private Candidate c;

    @BeforeEach
    void setUp() {
        c = new Candidate(7);
    }

    @Test
    void negativeDKeepsY() {
        c.f(3, -1.0);
        assertEquals(3, c.getX());
    }

    @Test
    void positiveDNegatesY() {
        c.f(3, 1.0);
        assertEquals(-3, c.getX());
    }

    @Test
    void resetSetsFortyTwo() {
        c.reset();                                   // protected, but we are in the same package
        assertEquals(42, c.getX());
    }

    @Test
    void deliberateFailure() {
        assertEquals(8, c.getX());                   // wrong on purpose, to show a failure report
    }

    @Test
    @Disabled("waiting for stage 04")
    void notYet() {
    }

    private static void assertEquals(int expected, int actual) {
        if (expected != actual) throw new AssertionError("expected " + expected + " but was " + actual);
    }
}
