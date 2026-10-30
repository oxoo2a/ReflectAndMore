# Stage 00: plain Java

_Java 25+37-LTS-jvmci-b01, Java HotSpot(TM) 64-Bit Server VM (Oracle Corporation), /Users/sturm/.sdkman/candidates/java/25-graal_

## Using Candidate the ordinary way

| Expression                           | Result                               |
|--------------------------------------|--------------------------------------|
| `a = new Candidate(7); a.f(3, -1.0)` | Candidate{x=3, label='candidate#7'}  |
| `b = new Candidate()`                | Candidate{x=42, label='candidate#0'} |
| `Candidate.created()`                | 2                                    |

## What this program cannot do

- describe Candidate (its fields, constructors, methods) without reading its source code
- call secret() or the private constructor
- create an instance of a class whose name becomes known only while the program runs
- decorate, replace or wire Candidate without editing Main

> ℹ Every call in this program was resolved when javac ran. The following stages remove these limits one by one.
