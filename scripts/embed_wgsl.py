#!/usr/bin/env python3
"""Regenerate the <script type="text/wgsl"> embed in webgpu/index.html from
webgpu/shaders/mhd_stencil.wgsl.

Why: file:// pages cannot fetch() (origin 'null' is CORS-blocked by every
Chromium), so a double-clicked index.html must carry its shader inline.
The .wgsl file stays the authoring source (syntax highlighting, diffs,
mirror tests); the embed is generated.

Usage:
    python3 scripts/embed_wgsl.py          # rewrite the embed in place
    python3 scripts/embed_wgsl.py --check  # exit 1 on drift (CI gate)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WGSL = ROOT / "webgpu" / "shaders" / "mhd_stencil.wgsl"
HTML = ROOT / "webgpu" / "index.html"

BEGIN = "/* embed:begin"
END = "/* embed:end */"
BANNER = ("/* embed:begin (generated from shaders/mhd_stencil.wgsl by "
          "scripts/embed_wgsl.py — do not edit here) */")


def build_embed() -> str:
    src = WGSL.read_text(encoding="utf-8").rstrip("\n")
    if "</script" in src:
        raise SystemExit(f"{WGSL}: contains '</script' — cannot embed verbatim")
    return f"{BANNER}\n{src}\n{END}\n"


def patch(html: str, mode: str) -> int:
    pattern = re.compile(
        re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?",
        re.DOTALL,
    )
    match = pattern.search(html)
    if not match:
        raise SystemExit(f"{HTML}: embed markers not found")
    new_block = build_embed()
    if mode == "check":
        return 0 if match.group(0) == new_block else 1
    return html[: match.start()] + new_block + html[match.end():]


def main(argv: list[str]) -> int:
    check = "--check" in argv[1:]
    html = HTML.read_text(encoding="utf-8")
    if check:
        ok = patch(html, "check") == 0
        if ok:
            print("embed in sync with", WGSL.name)
            return 0
        print("DRIFT: regenerate with python3 scripts/embed_wgsl.py",
              file=sys.stderr)
        return 1
    HTML.write_text(patch(html, "write"), encoding="utf-8")
    print("embed regenerated from", WGSL.name)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
