// Entry point for the HTML export that becomes the EPUB. No title page, no outline:
// the packager adds cover, title page and navigation itself.
#import "template.typ": *

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
