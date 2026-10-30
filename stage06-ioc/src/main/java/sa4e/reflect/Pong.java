package sa4e.reflect;

/** Field-injection cycle with Ping. */
@Component
public final class Pong {
    @Inject
    Ping ping;
}
