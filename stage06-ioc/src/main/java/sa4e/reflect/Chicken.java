package sa4e.reflect;

/** Constructor-injection cycle with Egg: cannot be satisfied. */
@Component
public final class Chicken {
    private final Egg egg;

    @Inject
    public Chicken(Egg egg) {
        this.egg = egg;
    }
}
