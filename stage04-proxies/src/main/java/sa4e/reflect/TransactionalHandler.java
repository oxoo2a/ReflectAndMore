package sa4e.reflect;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;

/**
 * Wraps calls to {@code @Transactional} methods in begin / commit, or rollback if the method
 * throws. Methods without the annotation pass through untouched. This is the core of EJB
 * container-managed transactions and Spring's {@code @Transactional}.
 */
public final class TransactionalHandler implements InvocationHandler, Forwarding {

    private final Object target;
    private final TransactionLog transactions;

    public TransactionalHandler(Object target, TransactionLog transactions) {
        this.target = target;
        this.transactions = transactions;
    }

    @Override
    public Object target() {
        return target;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        Method implementation = Proxies.implementationMethod(target, method);
        if (!implementation.isAnnotationPresent(Transactional.class)) {
            return Proxies.invokeTarget(target, method, args);
        }
        int tx = transactions.begin(Proxies.signature(method, args));
        try {
            Object result = Proxies.invokeTarget(target, method, args);
            transactions.commit(tx);
            return result;
        } catch (Throwable t) {
            transactions.rollback(tx, t);
            throw t;
        }
    }
}
