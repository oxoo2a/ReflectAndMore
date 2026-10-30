package sa4e.reflect;

import java.util.ArrayList;
import java.util.List;

/** Stands in for a transaction manager: it only records begin, commit and rollback. */
public final class TransactionLog {

    private final List<String> entries = new ArrayList<>();
    private int counter;

    public int begin(String reason) {
        int id = ++counter;
        entries.add("begin tx" + id + " for " + reason);
        return id;
    }

    public void commit(int id) {
        entries.add("commit tx" + id);
    }

    public void rollback(int id, Throwable cause) {
        entries.add("rollback tx" + id + " because of " + cause.getClass().getSimpleName());
    }

    public List<String> entries() {
        return entries;
    }
}
