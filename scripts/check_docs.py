#!/usr/bin/env python3
"""Check the pages in docs/ against each other.

The site is hand-written HTML and JavaScript, so nothing else notices when a page loses its theme
toggle, points at a script that is not there, or sends a reader to an anchor that no longer exists.
This does, and the CI runs it on every push.

    python3 scripts/check_docs.py

What it checks:

  * every relative href and src resolves to a file in docs/, except the engine, which the docs
    workflow builds;
  * every in-page anchor points at an id the page carries;
  * every page carries the same header: the four sections, the repository, the theme toggle, and
    the stylesheet;
  * the pages with a board load the menu script that gives the board its own right click.

It reads the files as text with a small regular expression rather than a parser, because the pages
are ours and the shapes it looks for are ones we control.
"""

from __future__ import annotations

import html
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
SECTIONS = ["index.html", "guide.html", "demo.html", "api.html"]
GENERATED = {"engine"}  # built into docs/ by the docs workflow, never committed

LINK = re.compile(r'(?:href|src)="([^"]+)"')
ANCHOR = re.compile(r'<a\b[^>]*href="#([^"]+)"')
ID = re.compile(r'\bid="([^"]+)"')
HREF = re.compile(r'<a\b[^>]*href="([^"]+)"')


def pages():
    for name in sorted(os.listdir(DOCS)):
        if name.endswith(".html"):
            yield name, io.open(os.path.join(DOCS, name), encoding="utf-8").read()


def check_links(name: str, text: str, problems: list[str]) -> None:
    for target in LINK.findall(text):
        target = html.unescape(target)
        if target.startswith(("http://", "https://", "mailto:", "data:", "#")):
            continue
        path = target.split("#")[0].split("?")[0]
        if not path or path.split("/")[0] in GENERATED:
            continue
        if not os.path.exists(os.path.join(DOCS, path)):
            problems.append(f"{name}: {target} is not in docs/")


def check_anchors(name: str, text: str, problems: list[str]) -> None:
    ids = set(ID.findall(text))
    for anchor in ANCHOR.findall(text):
        if anchor not in ids:
            problems.append(f"{name}: #{anchor} names no id on the page")


def check_header(name: str, text: str, problems: list[str]) -> None:
    header = re.search(r'<header class="top">(.*?)</header>', text, re.S)
    if not header:
        problems.append(f"{name}: no header")
        return
    links = {html.unescape(href) for href in HREF.findall(header.group(1))}
    for section in SECTIONS:
        if section not in links:
            problems.append(f"{name}: the header does not link to {section}")
    if not any(link.startswith("https://github.com/") for link in links):
        problems.append(f"{name}: the header has no repository link")
    if "data-theme-toggle" not in header.group(1):
        problems.append(f"{name}: the header has no theme toggle")
    if 'href="styles.css"' not in text:
        problems.append(f"{name}: no stylesheet")
    if "<footer>" not in text:
        problems.append(f"{name}: no footer")


def main() -> int:
    problems: list[str] = []
    count = 0
    for name, text in pages():
        count += 1
        check_links(name, text, problems)
        check_anchors(name, text, problems)
        check_header(name, text, problems)
    # A board reaches its menu through the module that drives it, so the import is checked where
    # it lives rather than in the page.
    for module in ("showcase.js", "demo.js", "bench.js"):
        text = io.open(os.path.join(DOCS, module), encoding="utf-8").read()
        if "menu.js" not in text:
            problems.append(f"docs/{module}: does not import the menu module")

    if problems:
        for problem in problems:
            print(problem)
        return 1
    print(f"docs: {count} pages, links, anchors and headers agree")
    return 0


if __name__ == "__main__":
    sys.exit(main())
