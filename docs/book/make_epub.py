#!/usr/bin/env python3
"""Packages the HTML exported by Typst into an EPUB 3 file.

Usage: make_epub.py <exported.html> <out.epub> --version "..." --built "..."
The exported HTML is split into chapters at <hr class="chapter-break">; each chapter becomes
one XHTML document. Inline data: images are extracted into files. A cover page, a title page,
a navigation document and a stylesheet are added.
"""
import argparse
import base64
import datetime
import re
import uuid
import zipfile
from pathlib import Path

from lxml import etree, html

HERE = Path(__file__).parent
XHTML_NS = "http://www.w3.org/1999/xhtml"
EPUB_NS = "http://www.idpf.org/2007/ops"

TITLE = "ReflectAndMore"
SUBTITLE = "A field guide to Java meta-programming, or: how enterprise frameworks work, built by hand in eight stages"
AUTHOR = "Claude"
AFFILIATION = "Software Architectures for Enterprises · Universität Trier"
DATE_LINE = "Inspired by a discussion with Peter Sturm · Winter term 2026/27"

CSS = """
html { font-size: 100%; }
body { font-family: Charter, Georgia, "Iowan Old Style", serif; line-height: 1.5; margin: 0 0.6em; color: #1f2328; }
h1, h2, h3, h4 { font-family: "Avenir Next", "Helvetica Neue", Arial, sans-serif; color: #1f5f8b; font-weight: 600; line-height: 1.2; }
h1 { font-size: 1.9em; margin: 0.2em 0 0.3em 0; }
h2 { font-size: 1.25em; margin: 1.4em 0 0.4em 0; color: #1f2328; }
h3 { font-size: 1.05em; margin: 1.1em 0 0.3em 0; }
nav#toc ol { list-style: none; margin-left: 0; } nav#toc ol ol { margin-left: 1.2em; font-size: 0.92em; } nav#toc li { margin-bottom: 0.35em; }
p { margin: 0 0 0.75em 0; text-align: left; }
p.stage { font-family: "Avenir Next", "Helvetica Neue", Arial, sans-serif; font-size: 0.8em; letter-spacing: 0.15em; color: #777; margin: 1.5em 0 0.2em 0; }
p.tagline { font-style: italic; color: #555; margin-bottom: 1.4em; }
p.src { font-family: "Avenir Next", "Helvetica Neue", Arial, sans-serif; font-size: 0.72em; color: #888; text-align: right; margin: -0.5em 0 1em 0; }
code { font-family: "Source Code Pro", Menlo, Consolas, monospace; font-size: 0.86em; background: #f3f4f6; border-radius: 3px; padding: 0 0.15em; }
pre { font-family: "Source Code Pro", Menlo, Consolas, monospace; font-size: 0.76em; line-height: 1.4; background: #f3f4f6; border-left: 3px solid #c8c8c8; padding: 0.6em 0.7em; margin: 0.8em 0; white-space: pre-wrap; word-wrap: break-word; border-radius: 3px; }
pre code { background: none; padding: 0; font-size: 1em; }
table { border-collapse: collapse; width: 100%; margin: 0.8em 0 1em 0; font-size: 0.86em; }
th { text-align: left; font-family: "Avenir Next", "Helvetica Neue", Arial, sans-serif; font-weight: 600; border-bottom: 1px solid #777; padding: 0.3em 0.4em; }
td { vertical-align: top; border-bottom: 1px solid #ddd; padding: 0.3em 0.4em; }
table.results td code { background: none; padding: 0; word-break: break-word; }
aside.callout { border-left: 3px solid #1f5f8b; background: #eef3f8; padding: 0.5em 0.8em; margin: 1em 0; border-radius: 3px; font-size: 0.95em; }
aside.callout p.callout-title { font-family: "Avenir Next", "Helvetica Neue", Arial, sans-serif; font-weight: 600; font-size: 0.85em; margin: 0 0 0.3em 0; color: #1f5f8b; }
aside.wild { border-color: #3a7d44; background: #edf5ee; } aside.wild p.callout-title { color: #3a7d44; }
aside.bill { border-color: #b8521f; background: #f9efe9; } aside.bill p.callout-title { color: #b8521f; }
aside.tryit { border-color: #6b4c9a; background: #f1edf7; } aside.tryit p.callout-title { color: #6b4c9a; }
aside.takeaway { border-color: #1f2328; background: #eeeeee; } aside.takeaway p.callout-title { color: #1f2328; }
aside.callout ul, aside.callout ol { margin: 0.2em 0 0.2em 1.2em; padding: 0; }
ul, ol { margin: 0.3em 0 0.8em 1.4em; padding: 0; }
li { margin-bottom: 0.25em; }
figure { margin: 1em 0; text-align: center; }
figure img { max-width: 100%; height: auto; }
figcaption { font-family: "Avenir Next", "Helvetica Neue", Arial, sans-serif; font-size: 0.8em; color: #666; margin-top: 0.4em; text-align: left; }
hr.chapter-break { display: none; }
.titlepage { text-align: left; margin-top: 15%; }
.titlepage p.affiliation { font-family: "Avenir Next", "Helvetica Neue", Arial, sans-serif; font-size: 0.8em; letter-spacing: 0.12em; color: #777; text-transform: uppercase; }
.titlepage h1 { font-size: 2.6em; margin: 1em 0 0.3em 0; }
.titlepage p.subtitle { font-family: "Avenir Next", "Helvetica Neue", Arial, sans-serif; font-size: 1.1em; color: #333; margin-bottom: 3em; }
.titlepage p.author { font-family: "Avenir Next", "Helvetica Neue", Arial, sans-serif; font-size: 1.1em; margin: 0; }
.titlepage p.meta { font-family: "Avenir Next", "Helvetica Neue", Arial, sans-serif; font-size: 0.85em; color: #777; margin: 0.2em 0; }
.cover { text-align: center; margin: 0; padding: 0; }
.cover img { max-width: 100%; max-height: 100%; }
"""


def slug(text, used):
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-") or "section"
    base, n = s, 1
    while s in used:
        n += 1
        s = f"{base}-{n}"
    used.add(s)
    return s


def xhtml_document(title, body_children, extra_class=None):
    root = etree.Element("{%s}html" % XHTML_NS, nsmap={None: XHTML_NS, "epub": EPUB_NS})
    head = etree.SubElement(root, "{%s}head" % XHTML_NS)
    etree.SubElement(head, "{%s}title" % XHTML_NS).text = title
    link = etree.SubElement(head, "{%s}link" % XHTML_NS)
    link.set("rel", "stylesheet"); link.set("type", "text/css"); link.set("href", "style.css")
    body = etree.SubElement(root, "{%s}body" % XHTML_NS)
    if extra_class:
        body.set("class", extra_class)
    for child in body_children:
        body.append(child)
    return b'<?xml version="1.0" encoding="UTF-8"?>\n' + etree.tostring(root, method="xml", encoding="utf-8", pretty_print=False)


def to_xhtml_tree(el):
    """Re-creates an lxml.html element as a namespaced XHTML element (recursively)."""
    tag = el.tag if isinstance(el.tag, str) else None
    if tag is None:
        return None
    # Typst exports its level-1 headings as <h2>; promote so that chapters are <h1>
    tag = {"h2": "h1", "h3": "h2", "h4": "h3", "h5": "h4"}.get(tag, tag)
    new = etree.Element("{%s}%s" % (XHTML_NS, tag))
    for k, v in el.attrib.items():
        new.set(k, v)
    new.text = el.text
    for child in el:
        sub = to_xhtml_tree(child)
        if sub is not None:
            new.append(sub)
        # keep the text that followed a dropped comment
    new.tail = el.tail
    return new


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("out")
    ap.add_argument("--version", default="")
    ap.add_argument("--built", default="")
    ap.add_argument("--cover", required=True, help="cover image (build-epub.sh renders the title page)")
    args = ap.parse_args()

    doc = html.fromstring(Path(args.source).read_text(encoding="utf-8"))
    body = doc.find("body")

    # split into chapters at <hr class="chapter-break">
    chapters, current = [], []
    for el in body:
        if el.tag == "hr" and el.get("class") == "chapter-break":
            if current:
                chapters.append(current)
            current = []
            continue
        current.append(el)
    if current:
        chapters.append(current)

    files = {}            # path inside OEBPS -> bytes
    manifest = []         # (id, href, media-type, properties)
    spine = []            # ids
    nav_entries = []      # (chapter title, href, [(section title, href)])
    used_ids = set()
    image_counter = 0

    for n, elements in enumerate(chapters, 1):
        xh = [to_xhtml_tree(e) for e in elements]
        xh = [e for e in xh if e is not None]
        # chapter title and section ids
        title = "Chapter %d" % n
        sections = []
        for e in xh:
            for h in e.iter("{%s}h1" % XHTML_NS, "{%s}h2" % XHTML_NS):
                text = "".join(h.itertext()).strip()
                if h.tag.endswith("h1"):
                    title = text
                else:
                    hid = slug(text, used_ids)
                    h.set("id", hid)
                    sections.append((text, hid))
            # extract inline images
            for img in e.iter("{%s}img" % XHTML_NS):
                src = img.get("src", "")
                if src.startswith("data:"):
                    header, data = src.split(",", 1)
                    mime = header[5:].split(";")[0]
                    ext = {"image/svg+xml": "svg", "image/png": "png", "image/jpeg": "jpg"}.get(mime, "bin")
                    image_counter += 1
                    name = f"images/figure-{image_counter}.{ext}"
                    files[name] = base64.b64decode(data)
                    manifest.append((f"img{image_counter}", name, mime, None))
                    img.set("src", name)
                if not img.get("alt"):
                    img.set("alt", "")
        href = f"chapter-{n:02d}.xhtml"
        files[href] = xhtml_document(title, xh)
        manifest.append((f"ch{n}", href, "application/xhtml+xml", None))
        spine.append(f"ch{n}")
        nav_entries.append((title, href, sections))

    # cover image (scaled down for the e-reader) and cover page
    from PIL import Image
    im = Image.open(args.cover).convert("RGB")
    im.thumbnail((1200, 1600))
    import io
    buf = io.BytesIO(); im.save(buf, format="JPEG", quality=85)
    files["images/cover.jpg"] = buf.getvalue()
    manifest.insert(0, ("cover-image", "images/cover.jpg", "image/jpeg", "cover-image"))
    cover_body = html.fromstring('<div class="cover"><img src="images/cover.jpg" alt="Cover"/></div>')
    files["cover.xhtml"] = xhtml_document("Cover", [to_xhtml_tree(cover_body)])
    manifest.insert(1, ("cover", "cover.xhtml", "application/xhtml+xml", None))

    # title page
    meta_lines = [DATE_LINE] + ([f"{args.version} · built {args.built}" if args.built else args.version] if args.version else [])
    tp = html.fromstring(
        '<div class="titlepage"><p class="affiliation">%s</p><h1>%s</h1><p class="subtitle">%s</p>'
        '<p class="author">%s</p>%s</div>' % (
            AFFILIATION, TITLE, SUBTITLE, AUTHOR,
            "".join('<p class="meta">%s</p>' % m for m in meta_lines)))
    files["title.xhtml"] = xhtml_document(TITLE, [to_xhtml_tree(tp)])
    manifest.insert(2, ("title", "title.xhtml", "application/xhtml+xml", None))

    # navigation document
    nav_items = []
    for title, href, sections in nav_entries:
        sub = ""
        if sections:
            sub = "<ol>" + "".join(f'<li><a href="{href}#{sid}">{etree_escape(t)}</a></li>' for t, sid in sections) + "</ol>"
        nav_items.append(f'<li><a href="{href}">{etree_escape(title)}</a>{sub}</li>')
    nav_html = ('<nav epub:type="toc" id="toc"><h1>Contents</h1><ol>%s</ol></nav>'
                '<nav epub:type="landmarks" hidden="hidden"><ol>'
                '<li><a epub:type="cover" href="cover.xhtml">Cover</a></li>'
                '<li><a epub:type="toc" href="nav.xhtml#toc">Table of contents</a></li>'
                '<li><a epub:type="bodymatter" href="chapter-01.xhtml">Start</a></li></ol></nav>') % "".join(nav_items)
    nav_doc = (b'<?xml version="1.0" encoding="UTF-8"?>\n'
               b'<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">'
               b'<head><title>Contents</title><link rel="stylesheet" type="text/css" href="style.css"/></head><body>'
               + nav_html.encode("utf-8") + b'</body></html>')
    etree.fromstring(nav_doc)  # well-formedness check
    files["nav.xhtml"] = nav_doc
    manifest.insert(3, ("nav", "nav.xhtml", "application/xhtml+xml", "nav"))
    files["style.css"] = CSS.strip().encode("utf-8")
    manifest.append(("css", "style.css", "text/css", None))

    # package document
    book_id = "urn:uuid:" + str(uuid.uuid5(uuid.NAMESPACE_URL, "https://deethou/Teach/ReflectAndMore/" + args.version))
    modified = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    items = "".join(
        f'<item id="{i}" href="{h}" media-type="{m}"{" properties=%s" % quote(p) if p else ""}/>'
        for i, h, m, p in manifest)
    itemrefs = '<itemref idref="cover" linear="no"/><itemref idref="title"/><itemref idref="nav"/>' + "".join(
        f'<itemref idref="{s}"/>' for s in spine)
    opf = f'''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="en">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="bookid">{book_id}</dc:identifier>
    <dc:title>{TITLE}</dc:title>
    <dc:creator>{AUTHOR}</dc:creator>
    <dc:language>en</dc:language>
    <dc:description>{etree_escape(SUBTITLE)}</dc:description>
    <dc:publisher>{etree_escape(AFFILIATION)}</dc:publisher>
    <meta property="dcterms:modified">{modified}</meta>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>{items}</manifest>
  <spine>{itemrefs}</spine>
</package>'''
    etree.fromstring(opf.encode("utf-8"))
    container = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>'''

    # well-formedness of every XHTML document
    for name, data in files.items():
        if name.endswith(".xhtml"):
            etree.fromstring(data)

    out = Path(args.out)
    with zipfile.ZipFile(out, "w") as z:
        z.writestr(zipfile.ZipInfo("mimetype"), "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        z.writestr("META-INF/container.xml", container, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/content.opf", opf, compress_type=zipfile.ZIP_DEFLATED)
        for name, data in files.items():
            z.writestr("OEBPS/" + name, data, compress_type=zipfile.ZIP_DEFLATED)
    print(f"wrote {out} ({out.stat().st_size // 1024} KB, {len(chapters)} chapters)")


def quote(s):
    return '"%s"' % s


def etree_escape(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


if __name__ == "__main__":
    main()
