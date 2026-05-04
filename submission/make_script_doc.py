"""Generate the Presentation Script Word document for submission.

Sourced directly from `PRESENTATION_SCRIPT.md` so the prose script that
drives the deck and the Word version stay perfectly in sync.

Run:
    python submission/make_script_doc.py
"""
from __future__ import annotations

from pathlib import Path

from _md_to_docx import build_document


HERE = Path(__file__).resolve().parent
SRC = HERE / "PRESENTATION_SCRIPT.md"
OUT_PATH = HERE / "Makuvaza_Tanaka_Vibzcheck_Project2_Presentation_Script.docx"


HEADER = {
    "Speaker": "Tanaka Makuvaza",
    "Course": "CSC 6370 - Mobile App Development",
    "CRN": "13598",
    "Student ID": "002252191",
    "Project": "Vibzcheck - Final Project (Project 2), Solo (M.S. graduate track)",
    "Length": "22 minutes spoken (rubric window 20-25 min)",
}

INTRO = (
    "Slide-by-slide speaker script for the 18-slide Vibzcheck "
    "presentation, with timing budget and a rehearsal checklist at the "
    "bottom. Quoted ('Say.') paragraphs are the spoken text; everything "
    "else is stage direction. The deck "
    "(Vibzcheck_Presentation.pptx) is generated from the same source "
    "narrative, so the two formats never drift apart."
)


def main() -> None:
    doc = build_document(
        title="Vibzcheck - Presentation Script",
        header_pairs=HEADER,
        intro=INTRO,
        markdown_path=SRC,
        skip_first_heading=True,
    )
    doc.save(OUT_PATH)
    print(f"Wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
