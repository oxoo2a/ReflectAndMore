// Book template: fonts, page layout, chapter openers, callout boxes.

#let body-font = "Charter"
#let head-font = "Avenir Next"
#let code-font = "Source Code Pro"

#let accent = rgb("#1f5f8b")      // blue: headings, links
#let accent-2 = rgb("#b8521f")    // orange: warnings
#let accent-3 = rgb("#3a7d44")    // green: real world
#let accent-4 = rgb("#6b4c9a")    // purple: try it
#let ink = rgb("#1f2328")
#let paper-gray = luma(246)

#let book(title: "", subtitle: "", author: "", affiliation: "", date: "", version: "", art: none, cover-image: none, body) = {
  set document(title: title, author: author)
  set page(
    paper: "a4",
    margin: (top: 2.6cm, bottom: 2.6cm, inside: 2.6cm, outside: 2.4cm),
    numbering: "1",
    number-align: center,
    header: context {
      let page-no = counter(page).get().first()
      let chapters = query(heading.where(level: 1)).filter(h => h.location().page() <= page-no)
      if chapters.len() > 0 and page-no > 1 {
        let h = chapters.last()
        set text(font: head-font, size: 8.5pt, fill: luma(110))
        if calc.odd(counter(page).get().first()) {
          align(right, smallcaps(h.body))
        } else {
          align(left, smallcaps(title))
        }
      }
    },
  )
  set text(font: body-font, size: 10.5pt, fill: ink, lang: "en")
  set par(justify: true, leading: 0.68em, spacing: 0.9em, first-line-indent: 0pt)
  show link: set text(fill: accent)

  // Headings
  show heading.where(level: 1): it => {
    set text(font: head-font, weight: "semibold", size: 26pt, fill: accent)
    block(it.body)
    v(0.9cm)
  }
  show heading.where(level: 2): it => {
    v(1.1em)
    set text(font: head-font, weight: "semibold", size: 14pt, fill: ink)
    block(it.body)
    v(0.25em)
  }
  show heading.where(level: 3): it => {
    v(0.7em)
    set text(font: head-font, weight: "medium", size: 11.5pt, fill: accent)
    block(it.body)
    v(0.1em)
  }
  set heading(numbering: none)

  // Code
  show raw: set text(font: code-font, size: 8.1pt)
  show raw.where(block: true): it => block(
    width: 100%,
    fill: paper-gray,
    stroke: (left: 2.5pt + luma(200)),
    inset: (x: 10pt, y: 8pt),
    radius: 2pt,
    breakable: true,
    it,
  )
  show raw.where(block: false): it => box(
    fill: paper-gray,
    inset: (x: 2pt, y: 0pt),
    outset: (y: 2.5pt),
    radius: 2pt,
    it,
  )

  // Tables
  set table(stroke: (x, y) => if y == 0 { (bottom: 0.8pt + luma(120)) } else { (bottom: 0.4pt + luma(210)) },
            inset: (x: 7pt, y: 5pt))
  show table.cell.where(y: 0): set text(font: head-font, weight: "semibold", size: 9pt)
  show table: set text(size: 9.5pt)
  show table: set par(justify: false)

  // Lists
  set list(indent: 1em, marker: text(fill: accent)[▪])
  set enum(indent: 1em)

  // Title page: a full-bleed photograph with the typography laid over it, or the drawn cover art.
  if cover-image != none {
    page(header: none, numbering: none, margin: 0pt)[
      #place(top + left)[#image(cover-image, width: 100%, height: 100%, fit: "cover")]
      // darken top and bottom a little so that white type stays legible
      #place(top + left)[#rect(width: 100%, height: 42%, fill: gradient.linear(rgb("#0a1a2e").transparentize(25%), rgb("#0a1a2e").transparentize(100%), angle: 90deg), stroke: none)]
      #place(bottom + left)[#rect(width: 100%, height: 22%, fill: gradient.linear(rgb("#0a1a2e").transparentize(100%), rgb("#0a1a2e").transparentize(20%), angle: 90deg), stroke: none)]
      #place(top + left, dx: 2.2cm, dy: 2.6cm)[
        #set text(font: head-font, fill: white)
        #text(size: 10pt, fill: white.transparentize(25%), tracking: 0.12em)[#upper(affiliation)]
        #v(1.2cm)
        #text(size: 44pt, weight: "bold")[#title]
        #v(0.5cm)
        #block(width: 14.5cm)[#text(size: 15pt, weight: "medium", fill: white.transparentize(10%))[#subtitle]]
      ]
      #place(bottom + left, dx: 2.2cm, dy: -2.2cm)[
        #set text(font: head-font, fill: white)
        #text(size: 13pt, weight: "medium")[#author]
        #linebreak()
        #text(size: 10.5pt, fill: white.transparentize(20%))[#date]
        #linebreak()
        #text(size: 9pt, fill: white.transparentize(40%))[#version]
      ]
    ]
  } else {
    page(header: none, numbering: none, margin: (top: 3.5cm, bottom: 2.5cm, x: 3cm))[
      #set text(font: head-font)
      #text(size: 11pt, fill: luma(110), tracking: 0.12em)[#upper(affiliation)]
      #v(1.4cm)
      #text(size: 40pt, weight: "bold", fill: accent)[#title]
      #v(0.6cm)
      #text(size: 17pt, weight: "medium", fill: ink)[#subtitle]
      #v(1fr)
      #align(center)[#art]
      #v(1fr)
      #text(size: 13pt, weight: "medium")[#author]
      #linebreak()
      #text(size: 10.5pt, fill: luma(100))[#date]
      #linebreak()
      #text(size: 9pt, fill: luma(140))[#version]
    ]
  }

  body
}

// Chapter opener: a stage number, a title and a tagline.
#let chapter(num: none, title: "", tagline: none) = {
  pagebreak(weak: true)
  v(2.2cm)
  if num != none {
    text(font: head-font, size: 12pt, weight: "medium", fill: luma(120), tracking: 0.15em)[#upper(num)]
    v(0.2cm)
  }
  heading(level: 1, title)
  v(-0.5cm)
  if tagline != none {
    block(width: 85%)[
      #set text(font: body-font, style: "italic", size: 11.5pt, fill: luma(90))
      #tagline
    ]
    v(0.6cm)
  }
}

// Callout boxes
#let callout(title, color, body) = block(
  width: 100%,
  fill: color.lighten(90%),
  stroke: (left: 3pt + color),
  inset: (x: 12pt, y: 9pt),
  radius: 2pt,
  breakable: true,
  above: 1.1em,
  below: 1.1em,
)[
  #text(font: head-font, weight: "semibold", size: 9.5pt, fill: color.darken(20%))[#title]
  #v(0.25em)
  #set text(size: 9.8pt)
  #body
]

#let note(body) = callout("Note", accent, body)
#let wild(body) = callout("In the wild", accent-3, body)
#let bill(body) = callout("The bill", accent-2, body)
#let tryit(body) = callout("Try it yourself", accent-4, body)
#let takeaway(body) = callout("Takeaways", ink, body)

// A caption-like label under a listing or output.
#let src(path) = {
  v(-0.6em)
  align(right, text(font: head-font, size: 8pt, fill: luma(120))[#path])
  v(0.2em)
}

// Program output rendered as a terminal-like block.
#let output(body) = block(
  width: 100%,
  fill: rgb("#f3f6f9"),
  stroke: (left: 2.5pt + accent.lighten(40%)),
  inset: (x: 10pt, y: 8pt),
  radius: 2pt,
  breakable: true,
)[
  #set text(font: code-font, size: 8.4pt)
  #body
]

// Expression/result table, the native rendering of what Report.kv prints.
#let results(..rows) = table(
  // long expressions get half the width, otherwise the first column takes what it needs
  columns: if rows.pos().map(r => r.at(0).len()).fold(0, calc.max) > 48 { (1fr, 1fr) } else { (auto, 1fr) },
  align: (left, left),
  [Expression], [Result],
  ..rows.pos().map(r => (
    text(font: code-font, size: 8.4pt, r.at(0)),
    text(font: code-font, size: 8.4pt, r.at(1)),
  )).flatten()
)

// Monospace text without the inline-code box, for table cells.
#let m(s) = text(font: code-font, size: 8.4pt, s)
