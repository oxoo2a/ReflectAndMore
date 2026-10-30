// This file is NOT compiled by the build. Stage 05 compiles it while the program runs.
public class Plugin implements sa4e.reflect.Capability {

    private int x;

    @Override
    public int getX() {
        return x;
    }

    @Override
    public void f(int y, double d) {
        x = y * 2;
    }

    @Override
    public String toString() {
        return "Plugin version 1 {x=" + x + "}";
    }
}
