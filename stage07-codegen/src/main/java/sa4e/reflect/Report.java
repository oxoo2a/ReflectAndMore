package sa4e.reflect;

import java.io.PrintStream;
import java.util.ArrayList;
import java.util.List;

/**
 * Prints the program output as Markdown. Markdown reads well in a terminal and becomes a
 * properly formatted document when redirected into a file ({@code ./run.sh 02 > output.md}).
 * <p>
 * This class is infrastructure and identical in every stage; it has nothing to do with the
 * mechanisms being demonstrated.
 */
public final class Report {

    private enum Kind { NONE, BLOCK, ITEM, NOTE }

    private final PrintStream out;
    private Kind last = Kind.NONE;
    private final List<String[]> pendingRows = new ArrayList<>();

    public Report(PrintStream out) {
        this.out = out;
    }

    public static Report stdout() {
        return new Report(System.out);
    }

    /** Document title plus the Java runtime, so it is always clear which installation ran. */
    public void title(String title) {
        separate(Kind.BLOCK);
        out.println("# " + title);
        out.println();
        out.println("_Java " + Runtime.version() + ", " + System.getProperty("java.vm.name")
                + " (" + System.getProperty("java.vendor") + "), " + System.getProperty("java.home") + "_");
    }

    public void heading(String heading) {
        separate(Kind.BLOCK);
        out.println("## " + heading);
    }

    /** A paragraph of plain text. */
    public void text(String fmt, Object... args) {
        separate(Kind.BLOCK);
        out.println(format(fmt, args));
    }

    /** A bullet point; consecutive items form one list. */
    public void item(String fmt, Object... args) {
        separate(Kind.ITEM);
        out.println("- " + format(fmt, args));
    }

    /** An explanatory remark, rendered as a block quote; consecutive notes form one quote. */
    public void note(String fmt, Object... args) {
        separate(Kind.NOTE);
        out.println("> ℹ " + format(fmt, args));
    }

    /** A fenced code block. */
    public void code(String language, String text) {
        separate(Kind.BLOCK);
        out.println("```" + language);
        out.print(text.endsWith("\n") ? text : text + "\n");
        out.println("```");
    }

    /**
     * One expression and its result. Consecutive calls are collected and rendered as a
     * two-column table when the next element of another kind is printed.
     */
    public void kv(String expression, Object value) {
        pendingRows.add(new String[]{"`" + expression + "`", cell(value)});
    }

    /** A table with a header row; cells are padded so that it is also readable in a terminal. */
    public void table(String[] header, List<String[]> rows) {
        separate(Kind.BLOCK);
        int columns = header.length;
        int[] width = new int[columns];
        for (int c = 0; c < columns; c++) width[c] = header[c].length();
        for (String[] row : rows) {
            for (int c = 0; c < columns; c++) width[c] = Math.max(width[c], row[c].length());
        }
        out.println(row(header, width));
        StringBuilder sep = new StringBuilder("|");
        for (int w : width) sep.append("-".repeat(w + 2)).append("|");
        out.println(sep);
        for (String[] r : rows) out.println(row(r, width));
    }

    /** Flushes a pending key/value table. Called automatically; call it at the very end. */
    public void flush() {
        if (pendingRows.isEmpty()) return;
        List<String[]> rows = new ArrayList<>(pendingRows);
        pendingRows.clear();
        table(new String[]{"Expression", "Result"}, rows);
    }

    private void separate(Kind next) {
        flush();
        if (last != Kind.NONE && (next == Kind.BLOCK || last == Kind.BLOCK || next != last)) {
            out.println();
        }
        last = next;
    }

    private static String format(String fmt, Object... args) {
        return args.length == 0 ? fmt : String.format(fmt, args);
    }

    private static String cell(Object value) {
        return String.valueOf(value).replace("|", "\\|").replace("\n", " ");
    }

    private static String row(String[] cells, int[] width) {
        StringBuilder sb = new StringBuilder("|");
        for (int c = 0; c < cells.length; c++) {
            sb.append(' ').append(cells[c]).append(" ".repeat(width[c] - cells[c].length())).append(" |");
        }
        return sb.toString();
    }
}
