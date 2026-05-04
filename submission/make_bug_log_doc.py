"""Generate the Bug Log Word document for submission.

Sourced directly from `BUG_LOG.md` so the two stay perfectly in sync.

Run:
    python submission/make_bug_log_doc.py
"""
from __future__ import annotations

from pathlib import Path

from _md_to_docx import build_document


HERE = Path(__file__).resolve().parent
SRC = HERE / "BUG_LOG.md"
OUT_PATH = HERE / "Makuvaza_Tanaka_Vibzcheck_Project2_Bug_Log.docx"


HEADER = {
    "Author": "Tanaka Makuvaza",
    "Course": "CSC 6370 - Mobile App Development",
    "CRN": "13598",
    "Student ID": "002252191",
    "Project": "Vibzcheck - Final Project (Project 2), Solo (M.S. graduate track)",
}

INTRO = (
    "Six hard-won bugs I hit while building Vibzcheck end-to-end, in "
    "the rubric's required format: Issue, Root cause, Fix, Affected "
    "files - plus the commit hash so anyone can inspect the exact "
    "diff in 'git log'. The 'Reflection' section at the bottom "
    "summarises the recurring pattern across the bugs and the tooling "
    "that caught each one early."
)


def main() -> None:
    doc = build_document(
        title="Vibzcheck - Bug Log",
        header_pairs=HEADER,
        intro=INTRO,
        markdown_path=SRC,
        skip_first_heading=True,
    )
    doc.save(OUT_PATH)
    print(f"Wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
