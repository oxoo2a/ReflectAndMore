package sa4e.reflect;

@Component("beta")
public final class DependencyB implements Dependency {
    @Override
    public String name() {
        return "beta";
    }
}
