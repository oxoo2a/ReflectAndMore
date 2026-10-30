// Renders the drawn illustration to an SVG for the HTML/EPUB build (see build-epub.sh).
#import "cover.typ": cover-art
#set page(width: auto, height: auto, margin: 0pt, fill: white)
#cover-art()
