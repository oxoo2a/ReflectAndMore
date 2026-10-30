# Stage 00: plain Java

The starting point. `Candidate` is an ordinary class with constructors, fields and methods of
every visibility. `Main` uses it the way every Java program uses a class: the compiler has seen
`Candidate.java`, so every call is resolved at compile time.

## What to notice

- `Main` can only use what is `public`. `secret()`, `reset()` and the private constructor are out of reach.
- `toString()` is a hand-written description of the object. Add a field and it is out of date.
- The class name `Candidate` is hard-coded. There is no way to create an object of a class that
  becomes known only at run time (from a configuration file, a plugin, a network message).
- Everything the program does is fixed when `javac` runs.

These limitations are the "pain" that each following stage removes with one more
meta-programming mechanism.

## Run

```
./run.sh 00
```

The output is Markdown; see [output.md](output.md) for the result of the last run.
