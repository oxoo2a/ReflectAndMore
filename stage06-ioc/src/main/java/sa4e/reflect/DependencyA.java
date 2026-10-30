package sa4e.reflect;

@Component("alpha")
public final class DependencyA implements Dependency {
    @Override
    public String name() {
        return "alpha";
    }
}
