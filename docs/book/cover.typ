// Cover illustration, drawn with Typst primitives: the Candidate class card on a mirror.
// In the reflection the private members are lit up, which is the whole book in one picture.
#import "template.typ": accent, accent-2, accent-3, accent-4, ink, head-font, code-font

#let card-width = 6.4cm

#let member(sign, text-body, color: ink, bold: false) = {
  set text(font: code-font, size: 8.2pt, fill: color, weight: if bold { "bold" } else { "regular" })
  box(width: 0.9em)[#sign]
  text-body
}

#let class-card(reflected: false) = {
  let priv = if reflected { accent-2 } else { ink }
  let b = reflected
  block(width: card-width, radius: 5pt, stroke: 1pt + accent, fill: white, clip: true, inset: 0pt)[
    #block(width: 100%, fill: accent, inset: (x: 11pt, y: 7pt))[
      #text(font: head-font, weight: "semibold", size: 11.5pt, fill: white)[Candidate]
      #h(1fr)
      #text(font: code-font, size: 7.5pt, fill: white.transparentize(30%))[sa4e.reflect]
    ]
    #block(width: 100%, inset: (x: 11pt, y: 7pt), spacing: 0pt)[
      #set par(leading: 0.55em)
      #member("−", [created : int], color: priv, bold: b) \
      #member("−", [x : int], color: priv, bold: b) \
      #member("−", [label : String], color: priv, bold: b)
    ]
    #line(length: 100%, stroke: 0.5pt + luma(205))
    #block(width: 100%, inset: (x: 11pt, y: 7pt), spacing: 0pt)[
      #set par(leading: 0.55em)
      #member("+", [Candidate(int)]) \
      #member("−", [Candidate(String)], color: priv, bold: b) \
      #member("+", [getX() : int]) \
      #member("+", [f(int, double)]) \
      #member("#", [reset()], color: if reflected { accent-2.lighten(20%) } else { ink }) \
      #member("−", [secret() : String], color: priv, bold: b)
    ]
  ]
}

#let badge(label, color) = box(
  fill: color.lighten(85%), stroke: 0.6pt + color.lighten(30%), radius: 8pt, inset: (x: 7pt, y: 3.5pt),
  text(font: code-font, size: 7.6pt, fill: color.darken(10%), label),
)

#let ghost(label, dx, dy) = place(top + left, dx: dx, dy: dy)[
  #block(width: card-width, height: 4.9cm, radius: 5pt, stroke: (paint: luma(175), thickness: 0.8pt, dash: "dashed"), fill: white.transparentize(40%))[
    #place(top + right, dx: -8pt, dy: 6pt)[#text(font: code-font, size: 7.2pt, fill: luma(150))[#label]]
  ]
]

#let cover-art() = box(width: 12.2cm, height: 9.8cm, clip: true)[
  // ghost cards: generated classes standing behind the real one
  #ghost("Candidate$$Intercepted", 5.3cm, 0.0cm)
  #ghost("$Proxy0", 4.8cm, 0.45cm)

  // the real class
  #place(top + left, dx: 4.3cm, dy: 0.9cm)[#class-card()]

  // annotations floating to the left, as if about to be attached
  #place(top + left, dx: 0.6cm, dy: 1.5cm)[#badge("@Component", accent-3)]
  #place(top + left, dx: 1.4cm, dy: 2.35cm)[#badge("@Inject", accent-4)]
  #place(top + left, dx: 0.3cm, dy: 3.2cm)[#badge("@Transactional", accent)]
  #place(top + left, dx: 0.9cm, dy: 4.05cm)[#badge("@Range(min, max)", accent-2)]
  #place(top + left, dx: 1.2cm, dy: 4.9cm)[#badge("@Comment", accent-3)]

  // the mirror
  #place(top + left, dx: 0cm, dy: 6.0cm)[
    #line(length: 12.2cm, stroke: (paint: gradient.linear(white, luma(150), accent.lighten(30%), luma(150), white), thickness: 1pt))
  ]
  #place(top + left, dx: 0.6cm, dy: 6.15cm)[
    #text(font: head-font, size: 7pt, fill: luma(140), tracking: 0.2em)[REFLECTION]
  ]

  // the reflection: flipped in place, private members lit up, fading out
  #place(top + left, dx: 4.3cm, dy: 6.08cm)[
    #scale(y: -100%, reflow: true)[#class-card(reflected: true)]
  ]
  #place(top + left, dx: 4.1cm, dy: 6.08cm)[
    #rect(width: card-width + 0.4cm, height: 3.8cm, fill: gradient.linear(white.transparentize(100%), white.transparentize(20%), white, angle: 90deg), stroke: none)
  ]
]
