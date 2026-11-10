#!/usr/bin/env python3
"""Fill the code the site shows from the tests that run it.

Every block on the site is a region of `src/examples/docs/<page>.mbt`, between
`// docs:begin <id>` and `// docs:end`. The lines outside those markers are the setup and
the asserts the page leaves out, so the block on the page is a fragment that still runs,
in `moon test`, without anyone pasting anything.

A page asks for a block with `<code data-snippet="<page>/<id>">`; this writes the marked
lines into it, set the way the pages already are — keywords in `k`, comments in `c` — so
a page cannot drift from the code that passes.

    python scripts/gen_docs_snippets.py           # rewrite the pages
    python scripts/gen_docs_snippets.py --check   # exit 1 if a page is stale
"""

from __future__ import annotations

import argparse
import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SNIPPETS = ROOT / "src" / "examples" / "docs"
DOCS = ROOT / "docs"

BEGIN = re.compile(r"^\s*//\s*docs:begin\s+(\S+)\s*$")
END = re.compile(r"^\s*//\s*docs:end\s*$")

KEYWORDS = {
    "as",
    "async",
    "break",
    "catch",
    "const",
    "continue",
    "else",
    "enum",
    "extern",
    "false",
    "fn",
    "for",
    "guard",
    "if",
    "impl",
    "in",
    "is",
    "let",
    "match",
    "mut",
    "pub",
    "raise",
    "return",
    "struct",
    "test",
    "trait",
    "true",
    "try",
    "type",
    "while",
}

WORD = re.compile(r"[A-Za-z_@][A-Za-z0-9_]*")


def regions(path: Path) -> dict[str, list[str]]:
    """`id -> lines` between the markers, with the common indent taken off."""
    out: dict[str, list[str]] = {}
    current: str | None = None
    buffer: list[str] = []
    for line in path.read_text(encoding="utf-8").split("\n"):
        begin = BEGIN.match(line)
        if begin:
            current, buffer = begin.group(1), []
            continue
        if END.match(line) and current is not None:
            body = [row.rstrip() for row in buffer]
            while body and not body[0].strip():
                body.pop(0)
            while body and not body[-1].strip():
                body.pop()
            indent = min(
                (len(row) - len(row.lstrip()) for row in body if row.strip()), default=0
            )
            out[current] = [row[indent:] if row.strip() else "" for row in body]
            current, buffer = None, []
            continue
        if current is not None:
            buffer.append(line)
    return out


def segments(line: str) -> list[tuple[str, str]]:
    """Split one line into `(class, text)` runs, class `""` for plain text."""
    out: list[tuple[str, str]] = []
    plain: list[str] = []

    def flush() -> None:
        if plain:
            out.append(("", "".join(plain)))
            plain.clear()

    i, n = 0, len(line)
    while i < n:
        if line.startswith("//", i):
            flush()
            out.append(("c", line[i:]))
            return out
        if line[i] == '"':
            j = i + 1
            while j < n:
                if line[j] == "\\":
                    j += 2
                    continue
                if line[j] == '"':
                    j += 1
                    break
                j += 1
            plain.append(line[i:j])
            i = j
            continue
        word = WORD.match(line, i)
        if word:
            text = word.group(0)
            if text in KEYWORDS:
                flush()
                out.append(("k", text))
            else:
                plain.append(text)
            i = word.end()
            continue
        plain.append(line[i])
        i += 1
    flush()
    return out


def split_comment(line: str) -> tuple[str, str]:
    """A line as `(code, comment)`, comment empty when the `//` is inside a string."""
    i = 0
    while i < len(line) - 1:
        if line[i] == "\\":
            i += 2
            continue
        if line[i] == '"':
            j = i + 1
            while j < len(line):
                if line[j] == "\\":
                    j += 2
                    continue
                if line[j] == '"':
                    j += 1
                    break
                j += 1
            i = j
            continue
        if line.startswith("//", i):
            return line[:i].rstrip(), line[i:]
        i += 1
    return line, ""


def aligned(lines: list[str]) -> list[str]:
    """The block with its trailing comments in one column.

    The formatter puts one space in front of a comment and refuses more, so the column is
    set here, where it is a matter of how the page reads: the same place the hand-written
    blocks had it.
    """
    pairs = [split_comment(line) for line in lines]
    target = max(
        (len(code) for code, comment in pairs if comment and code.strip()), default=0
    )
    out = []
    for code, comment in pairs:
        if comment and code.strip():
            out.append(code.ljust(target + 1) + comment)
        else:
            out.append(code + comment)
    return out


def as_html(lines: list[str]) -> str:
    lines = aligned(lines)
    out = []
    for line in lines:
        parts = []
        for cls, text in segments(line):
            escaped = html.escape(text, quote=False)
            parts.append(f'<span class="{cls}">{escaped}</span>' if cls else escaped)
        out.append("".join(parts))
    return "\n".join(out)


BLOCK = re.compile(r'(<code data-snippet="([^"]+)">)(.*?)(</code>)', re.S)


def fill(page: Path, snippets: dict[str, list[str]]) -> tuple[str, list[str]]:
    """The page with its blocks written in, and the ids it asked for."""
    text = page.read_text(encoding="utf-8")
    wanted: list[str] = []

    def block(m: re.Match) -> str:
        wanted.append(m.group(2))
        body = snippets.get(m.group(2))
        if body is None:
            raise SystemExit(f"{page.name}: no snippet for {m.group(2)}")
        return f"{m.group(1)}{as_html(body)}{m.group(4)}"

    return BLOCK.sub(block, text), wanted


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="report stale pages, write nothing")
    args = ap.parse_args()

    stale, total = [], 0
    for source in sorted(SNIPPETS.glob("*.mbt")):
        snippets = {f"{source.stem}/{key}": body for key, body in regions(source).items()}
        page = DOCS / f"{source.stem}.html"
        if not page.exists():
            raise SystemExit(f"{source.name}: no page {page.name}")
        filled, wanted = fill(page, snippets)
        total += len(wanted)
        missing = sorted(set(snippets) - set(wanted))
        if missing:
            raise SystemExit(f"{page.name}: {', '.join(missing)} is not on the page")
        if filled != page.read_text(encoding="utf-8"):
            stale.append(page.name)
            if not args.check:
                page.write_text(filled, encoding="utf-8", newline="\n")
    for page in stale:
        print(f"{page}: out of date")
    if args.check:
        return 1 if stale else 0
    pages = len(list(SNIPPETS.glob("*.mbt")))
    print(f"{total} blocks on {pages} pages written from the tests that run them")
    return 0


if __name__ == "__main__":
    sys.exit(main())
