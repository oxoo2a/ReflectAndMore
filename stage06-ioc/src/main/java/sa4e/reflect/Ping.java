package sa4e.reflect;

/** Field-injection cycle with Pong: can be satisfied, because objects exist before fields are set. */
@Component
public final class Ping {
    @Inject
    Pong pong;
}
