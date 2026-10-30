package sa4e.reflect;

/** Constructor-injection cycle with Chicken: cannot be satisfied. */
@Component
public final class Egg {
    private final Chicken chicken;

    @Inject
    public Egg(Chicken chicken) {
        this.chicken = chicken;
    }
}
