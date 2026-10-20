#!/usr/bin/env python3
"""Check the add-on's TOC pair.

X-Perl is one add-on: XPerl.toc is read by Mainline, XPerl_Camelot.toc by
WoW: Forever, and there must be no other TOC (left-over module TOCs would
show up as separate add-ons). The pair must list the same files and carry
the same metadata; only the Interface line may differ, and each must carry
the interface its client expects. Every listed file must exist with exactly
the case written in the TOC, since the client's file lookups are
case-sensitive on some platforms.
"""
import pathlib
import sys

MAINLINE_INTERFACE = "120100"
CAMELOT_INTERFACE = "16001"
MAINLINE_TOC = "XPerl.toc"
CAMELOT_TOC = "XPerl_Camelot.toc"

root = pathlib.Path(__file__).resolve().parents[2]
errors = []


def read(path):
    return path.read_text(encoding="utf-8-sig").splitlines()


def interface(lines, name):
    for line in lines:
        if line.startswith("## Interface:"):
            return line.split(":", 1)[1].strip()
    errors.append(f"{name}: no ## Interface line")
    return None


def exists_exact(relpath):
    """True if relpath (with / separators) exists below root with exactly this case."""
    current = root
    for part in relpath.split("/"):
        if not current.is_dir() or part not in {p.name for p in current.iterdir()}:
            return False
        current = current / part
    return True


for toc in sorted(root.rglob("*.toc")):
    if ".git" in toc.parts or ".release" in toc.parts:
        continue
    rel = toc.relative_to(root).as_posix()
    if rel not in (MAINLINE_TOC, CAMELOT_TOC):
        errors.append(f"{rel}: unexpected TOC; X-Perl ships only {MAINLINE_TOC} and {CAMELOT_TOC}")

mainline, camelot = root / MAINLINE_TOC, root / CAMELOT_TOC
for toc in (mainline, camelot):
    if not toc.exists():
        errors.append(f"missing {toc.name}")

if mainline.exists() and camelot.exists():
    mainline_lines, camelot_lines = read(mainline), read(camelot)
    if interface(mainline_lines, MAINLINE_TOC) != MAINLINE_INTERFACE:
        errors.append(f"{MAINLINE_TOC}: Interface should be {MAINLINE_INTERFACE}")
    if interface(camelot_lines, CAMELOT_TOC) != CAMELOT_INTERFACE:
        errors.append(f"{CAMELOT_TOC}: Interface should be {CAMELOT_INTERFACE}")

    strip = lambda lines: [l for l in lines if not l.startswith("## Interface:")]
    if strip(mainline_lines) != strip(camelot_lines):
        errors.append(f"{MAINLINE_TOC}: differs from {CAMELOT_TOC} beyond the Interface line")

    for line in strip(mainline_lines):
        line = line.strip()
        if line and not line.startswith("#") and not exists_exact(line.replace("\\", "/")):
            errors.append(f"{MAINLINE_TOC}: lists missing file {line} (paths are case-sensitive)")

for e in errors:
    print(e)
sys.exit(1 if errors else 0)
