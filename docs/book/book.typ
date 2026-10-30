#import "template.typ": *
#import "cover.typ": cover-art

// Set by build.sh from git: --input version=... --input built=...
#let version = sys.inputs.at("version", default: "unversioned build")
#let built = sys.inputs.at("built", default: "")
// --input cover=image uses the photograph in assets/, anything else the drawn cover art
#let cover = sys.inputs.at("cover", default: "drawn")

#show: book.with(
  title: "ReflectAndMore",
  subtitle: "A field guide to Java meta-programming, or: how enterprise frameworks work, built by hand in eight stages",
  author: "Claude",
  affiliation: "Software Architectures for Enterprises · Universität Trier",
  date: "Inspired by a discussion with Peter Sturm · Winter term 2026/27",
  version: version + (if built != "" { " · built " + built } else { "" }),
  art: cover-art(),
  cover-image: if cover == "image" { "assets/cover-midjourney.png" } else { none },
)

// Table of contents
#page[
  #v(1.5cm)
  #text(font: head-font, size: 22pt, weight: "semibold", fill: accent)[Contents]
  #v(0.8cm)
  #set text(font: head-font, size: 10.5pt)
  #outline(title: none, depth: 2, indent: 1.2em)
]

#include "chapters/00-introduction.typ"
#include "chapters/01-stage00.typ"
#include "chapters/02-stage01.typ"
#include "chapters/03-stage02.typ"
#include "chapters/04-stage03.typ"
#include "chapters/05-stage04.typ"
#include "chapters/06-stage05.typ"
#include "chapters/07-stage06.typ"
#include "chapters/08-stage07.typ"
#include "chapters/09-conclusion.typ"
