package sa4e.reflect;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;

/**
 * Client side of a remote call. The stub implements the interface, but instead of running the
 * method it marshals name and arguments into a request string, hands it to a transport and
 * unmarshals the reply. RMI stubs, SOAP client proxies, Feign and Retrofit are this with a
 * real network underneath.
 * <p>
 * Request: {@code method|paramType,paramType|arg|arg}, reply: {@code ok|value} or {@code error|message}.
 */
public final class RemoteStub {

    private RemoteStub() {}

    public static <T> T create(Class<T> type, Function<String, String> transport, List<String> wireLog) {
        return Proxies.wrap(type, (proxy, method, args) -> {
            if (method.getDeclaringClass() == Object.class) {            // toString etc. stay local
                return "RemoteStub[" + type.getSimpleName() + "]";
            }
            String request = marshal(method, args);
            wireLog.add("request: " + request);
            String reply = transport.apply(request);
            wireLog.add("reply:   " + reply);
            return unmarshal(reply);
        });
    }

    private static String marshal(Method method, Object[] args) {
        List<String> types = new ArrayList<>();
        for (Class<?> p : method.getParameterTypes()) types.add(Wire.typeName(p));
        StringBuilder sb = new StringBuilder(method.getName()).append('|').append(String.join(",", types));
        if (args != null) for (Object a : args) sb.append('|').append(Wire.encode(a));
        return sb.toString();
    }

    private static Object unmarshal(String reply) {
        int bar = reply.indexOf('|');
        String status = reply.substring(0, bar);
        String payload = reply.substring(bar + 1);
        if (status.equals("error")) throw new RuntimeException("remote: " + payload);
        return payload.equals("void") ? null : Wire.decode(payload);
    }
}
