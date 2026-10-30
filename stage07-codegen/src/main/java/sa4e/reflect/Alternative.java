package sa4e.reflect;

/** A second implementation of Capability, so that there is something to choose between. */
@Component
public final class Alternative implements Capability {

    private int x;

    @Override
    public int getX() {
        return x;
    }

    @Override
    public void f(int y, double d) {
        x = y + (int) d;
    }

    @Override
    public String toString() {
        return "Alternative{x=" + x + "}";
    }
}
