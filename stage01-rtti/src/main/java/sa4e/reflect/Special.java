package sa4e.reflect;

/** A subclass, so that static and dynamic type can differ and there is a hierarchy to walk. */
public class Special extends Candidate implements Comparable<Special> {

    public Special(int x) {
        super(x);
    }

    @Override
    public int compareTo(Special other) {
        return Integer.compare(getX(), other.getX());
    }
}
