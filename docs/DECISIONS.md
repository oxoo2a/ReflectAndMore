# Design decisions

The record of how ReflectAndMore came to look the way it does. The README explains *what* is
here and how to run it; this file explains *why*, so that the reasons survive the people who
made them. Decisions were taken in a discussion between Peter Sturm and Claude on 2026-10-30.

## Purpose

A demo for the lecture *Software Architectures for Enterprises* (Universität Trier), aimed at
master students who know Java but have never met meta-programming. One program grows through
eight stages, from a plain class to a hand-built IoC container and run-time code generation, so
that students see where frameworks such as Spring, Hibernate, JUnit and Jakarta EE get their
powers from.

## One folder per stage, one branch

Each stage is a complete, runnable Maven module in its own folder (`stage00-plain` …
`stage07-codegen`). Numbers have two digits so that more than nine stages remain possible.
The repository has a single `main` branch; a tag per semester (e.g. `2026W`) will mark the
state used in a given lecture.

Rejected: one branch or tag per stage. Updating a change across all stages would then mean
rebasing a chain of branches, and students would have to check out each stage. Folders let
everything be edited and viewed at once, and `tools/diff-stages.sh` still shows what a stage adds.

## No domain semantics

The inspected class is called `Candidate` and does nothing meaningful. Every helper is named
after its role in the mechanism: `Inspector`, `Invoker`, `Validator`, `Interceptor`, `Container`,
`Plugin`, `Dependency`, `Composite`. A customer or order domain would draw attention to the
business logic, which is exactly the part students should not have to think about here.

`Candidate` changes as little as possible between stages, and every change is announced in the
stage's README and in the book. Everything that grows is the framework around it.

## Same package and entry point everywhere

All stages use the package `sa4e.reflect` and the entry point `sa4e.reflect.Main`. Diffs
between neighbouring stages then show only the real step. Each stage's `Main` demonstrates only
the mechanism new to that stage; helper classes are carried forward only while they are still used.

## Java 25, English, pure JDK

No third-party libraries, so that nothing is hidden: every proxy, loader and container is in the
repository. Java 25 because the ClassFile API (`java.lang.classfile`) of stage 07 is final there.

## Output is Markdown

Every stage prints Markdown through an identical `Report` helper (title, headings, key/value
tables, notes, code). The output of each stage is committed as `output.md`, which makes the
results readable on the forge without running anything and doubles as a regression test:
`tools/save-outputs.sh --check` regenerates the outputs and compares them, ignoring values that
vary between runs (Java version line, benchmark timings, object addresses, hidden-class suffixes,
temporary paths).

## XML through StAX, not string concatenation

The `Inspector` of stages 02 to 04 writes its XML with the JDK's streaming writer
(`javax.xml.stream.XMLStreamWriter`, module `java.xml`), element by element. The writer escapes
attribute values and text and tracks the open elements, so the document is well-formed by
construction and the annotation values of stage 03 need no hand-written escaping. StAX does not
indent; three small helpers that wrap the start, empty and end element calls add a line break
and two spaces per nesting level, so the output stays readable without a pretty-printer.

Rejected: building the XML in a `StringBuilder` (the original version), which only hoped to be
well-formed and needed a side buffer to decide between `<field/>` and `<field>…</field>`;
DOM plus `Transformer`, which indents but adds `standalone="no"` and a vendor-specific indent
property; JAXB, Jackson or JDOM, which are not in the JDK.

## READMEs and the book

Each stage README follows the same rhythm: the pain in the previous stage, the mechanism, the new
files, where it appears in the real world, what it costs, exercises, how to run. The textbook in
`docs/` follows the same rhythm chapter by chapter and quotes the committed outputs.

The book is written in Typst (`docs/book/`), typeset in Charter, Avenir Next and Source Code Pro.
The PDF is the primary edition; the EPUB is built from the same sources through Typst's HTML
export and a small packager, for reading on phones and e-readers. The version line on the title
page is derived from git (tag, commit, "modified" if the tree is dirty), so the workflow is:
commit the sources, rebuild, commit the outputs.

The author of the book is Claude, "inspired by a discussion with Peter Sturm", at Peter Sturm's
request, since the text was written by Claude.

## Cover

The cover is the class-on-a-mirror illustration drawn in Typst (`docs/book/cover.typ`), which is
also Figure 1 of the introduction. Image covers generated with DALL·E and Midjourney from prompts
written for the book were tried and are kept as alternatives (`docs/book/build.sh dalle` or
`midjourney`), but the drawn version was preferred: less is more.

## Licenses

The code is under the MIT license, the book under CC BY 4.0, both with Peter Sturm as the
rights holder. Two licenses because the book travels alone as PDF and EPUB: readers of teaching
material expect Creative Commons terms, and MIT's wording is about software. CC BY rather than
BY-SA or BY-NC so that other courses, including paid programmes, can adapt the material with
nothing but attribution. The notice is in the colophon on the back cover and in the EPUB
metadata, so that it stays with the book outside the repository.

## Hosting

The repository lives on a self-hosted Forgejo instance (remote `deethou`), which is the
canonical copy, and is published on GitHub under Peter Sturm's personal account
(remote `github`, https://github.com/oxoo2a/ReflectAndMore) since 2026-11-03. Both remotes
receive every push.
A public GitHub mirror for students may be added later.

## Possible next steps

- Tag `2026W` after the lecture.
- Public mirror on GitHub.
- Reference solutions for the exercises.
