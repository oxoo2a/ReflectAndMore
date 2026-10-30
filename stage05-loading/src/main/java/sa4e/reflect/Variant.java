package sa4e.reflect;

/**
 * A sealed hierarchy with a record and a class, plus an enum. The compiler and the run time both
 * know the complete set of subtypes, and records and enums describe their own structure.
 */
public sealed interface Variant permits Variant.A, Variant.B {

    record A(int value, String tag) implements Variant {}

    final class B implements Variant {
        private final double weight;

        public B(double weight) {
            this.weight = weight;
        }

        public double weight() {
            return weight;
        }
    }

    enum Mode { ON, OFF, UNKNOWN }
}
