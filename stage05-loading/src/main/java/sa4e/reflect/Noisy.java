package sa4e.reflect;

/** A class whose static initializer leaves a trace, to show when initialization happens. */
public final class Noisy {

    static {
        LoadEvents.EVENTS.add("static initializer of Noisy ran");
    }

    public static final int CONSTANT = 42;          // compile-time constant: reading it does not initialize the class
    public static int counter = 1;                  // reading this does

    private Noisy() {}
}
