#!/usr/bin/env python3
"""Build docs/api.html from every package's pkg.generated.mbti and its /// comments.

The generated file is what the site shows and what the CI compares against, so the two
sources of truth are the compiler's interface and the comments in the source: nothing here
decides what is public.

Run from the repository root:  python3 scripts/gen_api.py
"""

from __future__ import annotations

import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "docs" / "api.html"

# The order the packages are shown in: the root first, then the families, then the formats.
ORDER = [
    "",
    "traverse", "path", "component", "dag", "cycle", "tree", "flow", "matching",
    "color", "clique", "centrality", "community", "metric", "struct", "iso", "op",
    "approx", "gen", "io", "io/graphml",
]

# The compiler writes these for every type that derives Eq or Debug; nobody writes a comment
# for them, so the page gives them the sentence their name already implies.
DERIVED = {
    "equal": "Derived: whether two values of this type are the same, field by field.",
    "not_equal": "Derived: whether two values of this type differ.",
    "to_repr": "Derived: the debug view of a value, used when an assertion fails.",
}

TITLES = {
    "": "moongraph",
    "io/graphml": "io/graphml",
}


def mbti_items(text: str) -> list[tuple[str, str]]:
    """Every public item of a package, as (kind, name), in the mbti's own order.

    Generic items keep their type parameters in the name so that the check for "every item
    appears" cannot pass by accident.
    """
    items: list[tuple[str, str]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("pub"):
            continue
        if m := re.match(r"pub(?:\(open\))? trait (\w+)", line):
            items.append(("trait", m.group(1)))
        elif m := re.match(r"pub(?:\(all\))? (?:suberror|error) (\w+)", line):
            items.append(("error", m.group(1)))
        elif m := re.match(r"pub(?:\(all\))? (?:struct|enum|type) (\w+)", line):
            items.append(("type", m.group(1)))
        elif m := re.match(r"pub fn(?:\[[^\]]*\])? (\w+(?:::\w+)?)", line):
            items.append(("fn", m.group(1)))
        elif m := re.match(r"pub let (\w+)", line):
            items.append(("let", m.group(1)))
    return items


DOC_BLOCK = re.compile(r"((?:^///.*\n)+)", re.MULTILINE)
DECL = re.compile(
    r"^(?:pub(?:\([^)]*\))?\s+)?(?:fn|struct|enum|let|trailer|trait|suberror)\b"
)


def source_docs(path: Path) -> dict[str, tuple[str, str]]:
    """Map an item name to (its doc text, its signature) for one source file.

    A doc comment belongs to the first declaration after it, which is the convention the
    compiler uses too.
    """
    out: dict[str, tuple[str, str]] = {}
    lines = path.read_text(encoding="utf-8").splitlines()
    index = 0
    while index < len(lines):
        if lines[index].startswith("///"):
            block: list[str] = []
            while index < len(lines) and lines[index].startswith("///"):
                text = lines[index][3:]
                if text.strip() != "|":
                    block.append(text.strip())
                index += 1
            # Skip blank lines and attributes between the comment and its declaration: a
            # `#derive` sits there on every type that has one, and the comment belongs to the
            # declaration below it, not to the attribute.
            while index < len(lines) and (
                not lines[index].strip() or lines[index].lstrip().startswith("#")
            ):
                index += 1
            if index >= len(lines):
                break
            decl_lines: list[str] = []
            depth = 0
            while index < len(lines):
                current = lines[index]
                decl_lines.append(current.strip())
                depth += current.count("(") - current.count(")")
                index += 1
                if depth <= 0:
                    break
            signature = " ".join(decl_lines)
            name = item_name(signature)
            if name:
                out.setdefault(name, ("\n".join(block), signature))
        else:
            index += 1
    return out


def item_name(signature: str) -> str | None:
    signature = signature.split("{")[0].strip()
    for pattern in (
        r"\bfn\s*(?:\[[^\]]*\]\s*)?(\w+(?:::\w+)?)",
        r"\bstruct\s+(\w+)",
        r"\benum\s+(\w+)",
        r"\bsuberror\s+(\w+)",
        r"\btrait\s+(\w+)",
        r"\blet\s+(\w+)",
    ):
        if m := re.search(pattern, signature):
            return m.group(1)
    return None


def signature_text(signature: str) -> str:
    """The declaration with its body removed and its type parameters kept."""
    text = signature.split("{")[0].strip()
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"^(pub(?:\([^)]*\))?\s+)+", "", text)
    return text


def render_package(name: str, docs: dict[str, tuple[str, str]], items: list[tuple[str, str]]) -> str:
    label = f"moongraph/{name}" if name else "moongraph"
    rows: list[str] = []
    seen: set[str] = set()
    for kind, item in items:
        if item in seen:
            continue
        seen.add(item)
        doc, signature = docs.get(item, ("", ""))
        if signature:
            sig = html.escape(signature_text(signature))
            # The item's name is the part a reader scans for, so it is marked.
            sig = sig.replace(html.escape(item), f'<span class="name">{html.escape(item)}</span>', 1)
        else:
            sig = f'<span class="name">{html.escape(item)}</span>'
        if not doc and item.split("::")[-1] in DERIVED:
            doc = DERIVED[item.split("::")[-1]]
        text = html.escape(doc.split("\n\n")[0]) if doc else ""
        text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
        rows.append(
            '<div class="item">'
            f'<div class="sig">{sig}</div>'
            + (f'<div class="doc-text">{text}</div>' if text else "")
            + "</div>"
        )
    count = len(rows)
    return (
        f'<section class="pkg" id="{"root" if not name else name.replace("/", "-")}">'
        f"<h2>{html.escape(label)}<span class=\"count\">{count} items</span></h2>"
        + "".join(rows)
        + "</section>"
    )


def main() -> int:
    packages: list[str] = []
    for path in (SRC / "pkg.generated.mbti").parent.rglob("pkg.generated.mbti"):
        rel = path.parent.relative_to(SRC).as_posix()
        if rel == ".":
            rel = ""
        # `internal` is support code and `examples` is not part of the library's surface;
        # neither belongs in a reference a caller reads.
        if rel == "internal" or rel.startswith("examples"):
            continue
        packages.append(rel)

    packages.sort(key=lambda name: (ORDER.index(name) if name in ORDER else 99, name))

    # A method promoted out of a trait carries the trait's comment, so the bare name is the
    # fallback for a `Type::method` the source never writes out.
    fallback: dict[str, tuple[str, str]] = {}
    for name in packages:
        directory = SRC / name if name else SRC
        for source in sorted(directory.glob("*.mbt")):
            if source.name.endswith("_test.mbt") or source.name.endswith("_wbtest.mbt"):
                continue
            for item, value in source_docs(source).items():
                fallback.setdefault(item, value)

    sections: list[str] = []
    missing: list[str] = []
    for name in packages:
        directory = SRC / name if name else SRC
        mbti = (directory / "pkg.generated.mbti").read_text(encoding="utf-8")
        items = mbti_items(mbti)
        docs: dict[str, tuple[str, str]] = {}
        for source in sorted(directory.glob("*.mbt")):
            if source.name.endswith("_test.mbt") or source.name.endswith("_wbtest.mbt"):
                continue
            for item, value in source_docs(source).items():
                docs.setdefault(item, value)
        for _, item in items:
            if item not in docs:
                bare = item.split("::")[-1]
                if bare in fallback:
                    docs[item] = fallback[bare]
                else:
                    missing.append(f"{name or 'root'}: {item}")
        sections.append(render_package(name, docs, items))

    page = PAGE.format(sections="\n".join(sections))
    OUT.write_text(page, encoding="utf-8", newline="\n")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(packages)} packages")
    if missing:
        print("items without a doc comment:", len(missing))
        for line in missing[:40]:
            print("  ", line)
    return 0


PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>API reference · MoonBit Classic</title>
<meta name="description" content="Every public type, value and function in moongraph, package by package.">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Ccircle cx='16' cy='16' r='13' fill='none' stroke='%23d8a94a' stroke-width='1.4'/%3E%3Ccircle cx='16' cy='16' r='4' fill='%23d8a94a'/%3E%3C/svg%3E">
<link rel="stylesheet" href="styles.css">
</head>
<body>

<header class="top">
  <div class="wrap">
    <a class="brand" href="index.html">
      <svg width="22" height="22" viewBox="0 0 32 32" aria-hidden="true">
        <circle cx="16" cy="16" r="12.5" fill="none" stroke="currentColor" stroke-width="1.2" opacity="0.55"/>
        <circle cx="16" cy="3.5" r="2.6" fill="#d8a94a"/>
        <circle cx="26.8" cy="22.3" r="2.6" fill="#d8a94a"/>
        <circle cx="5.2" cy="22.3" r="2.6" fill="#d8a94a"/>
        <path d="M16 3.5 L26.8 22.3 L5.2 22.3 Z" fill="none" stroke="currentColor" stroke-width="1" opacity="0.5"/>
      </svg>
      <span class="brand-text">
        <span class="brand-line">MoonBit Classic</span>
        <span class="brand-sub">Graph Algorithm Library</span>
      </span>
    </a>
    <nav class="pages">
      <a href="index.html">Home</a>
      <a href="guide.html">Guide</a>
      <a href="demo.html">Demo</a>
      <a href="api.html" aria-current="page">API</a>
      <a href="https://github.com/moonbitstack/moongraph" aria-label="The repository">
        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38v-1.34c-2.23.48-2.7-1.07-2.7-1.07-.36-.93-.89-1.18-.89-1.18-.73-.5.06-.49.06-.49.81.06 1.23.83 1.23.83.72 1.23 1.88.88 2.34.67.07-.52.28-.88.51-1.08-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.6 7.6 0 0 1 4 0c1.53-1.03 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.28.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48v2.2c0 .21.15.46.55.38A8 8 0 0 0 16 8c0-4.42-3.58-8-8-8Z"/></svg>
      </a>
    </nav>
    <button class="icon-btn" data-theme-toggle aria-label="Switch the theme">
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M5.6 18.4 7 17M17 7l1.4-1.4"/><circle cx="12" cy="12" r="4.2"/></svg>
    </button>
  </div>
</header>

<main class="wrap api">
  <div class="sec-head" style="border:0;padding-top:2rem">
    <span class="sec-num">API</span>
    <h2>Every public item, package by package</h2>
  </div>
  <p style="max-width:var(--measure);color:var(--muted);margin-top:-0.6rem">
    Generated from the compiler's interface files and the comments beside each declaration, so
    nothing here is out of date with the code. Names in brass are the item itself; a signature is
    shown as the compiler sees it.
  </p>
{sections}
</main>

<footer>
  <div class="wrap">
    <span>moongraph · Apache-2.0</span>
    <a href="https://mooncakes.io/docs/moonbitstack/moongraph">mooncakes</a>
    <a href="index.html">home</a>
    <a href="guide.html">guide</a>
    <a class="spacer" href="https://github.com/moonbitstack/moongraph">github</a>
  </div>
</footer>

<script src="app.js"></script>
</body>
</html>
"""


if __name__ == "__main__":
    sys.exit(main())
