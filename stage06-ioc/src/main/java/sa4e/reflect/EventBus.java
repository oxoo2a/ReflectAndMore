package sa4e.reflect;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

/**
 * Delivers posted events to {@code @Subscribe} methods whose single parameter type accepts the
 * event. Subscribers never call anything; the bus calls them. Guava's EventBus and Spring's
 * {@code @EventListener} are this with threading and error handling on top.
 */
public final class EventBus {

    private record Subscription(Object target, Method method, Class<?> eventType) {}

    private final List<Subscription> subscriptions = new ArrayList<>();

    public void register(Object subscriber) {
        for (Method m : subscriber.getClass().getDeclaredMethods()) {
            if (!m.isAnnotationPresent(Subscribe.class)) continue;
            if (m.getParameterCount() != 1) throw new IllegalArgumentException("@Subscribe method must have one parameter: " + m);
            m.setAccessible(true);
            subscriptions.add(new Subscription(subscriber, m, m.getParameterTypes()[0]));
        }
    }

    /** Delivers the event and returns how many subscribers received it. */
    public int post(Object event) {
        int delivered = 0;
        for (Subscription s : subscriptions) {
            if (!s.eventType().isInstance(event)) continue;
            try {
                s.method().invoke(s.target(), event);
                delivered++;
            } catch (InvocationTargetException e) {
                throw new RuntimeException("subscriber failed: " + e.getCause(), e.getCause());
            } catch (IllegalAccessException e) {
                throw new RuntimeException(e);
            }
        }
        return delivered;
    }

    public List<String> subscriptions() {
        List<String> result = new ArrayList<>();
        for (Subscription s : subscriptions) {
            result.add(s.target().getClass().getSimpleName() + "." + s.method().getName() + "(" + s.eventType().getSimpleName() + ")");
        }
        return result;
    }
}
