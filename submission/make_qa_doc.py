"""Generate the Word document with the **answers** to the curated questions.

The companion script `make_questions_only_doc.py` produces the
"questions only" deliverable required by the rubric. This script
produces the full Q&A version (questions + their researched answers
with code references) sourced directly from `CURATED_QUESTIONS.md`.

Run:
    python submission/make_qa_doc.py
"""
from __future__ import annotations

from pathlib import Path

from _md_to_docx import build_document


HERE = Path(__file__).resolve().parent
SRC = HERE / "CURATED_QUESTIONS.md"
OUT_PATH = HERE / (
    "Makuvaza_Tanaka_Vibzcheck_Project2_Curated_Questions_Answers.docx"
)


HEADER = {
    "Author": "Tanaka Makuvaza",
    "Course": "CSC 6370 - Mobile App Development",
    "CRN": "13598",
    "Student ID": "002252191",
    "Project": "Vibzcheck - Final Project (Project 2), Solo (M.S. graduate track)",
}

INTRO = (
    "This document is the answer key for the 14 curated questions I "
    "selected for the project defense, with code references back into "
    "the Vibzcheck repository. Coverage follows the official "
    "distribution: Implementation x3, Architecture x3, Testing x3, "
    "Firebase x4, Reflection x1. The companion 'questions only' Word "
    "document (Makuvaza_Tanaka_Vibzcheck_Project2_Curated_Questions.docx) "
    "is generated from the same source so the two never drift apart."
)


def main() -> None:
    doc = build_document(
        title="Vibzcheck - Curated Questions (Answers)",
        header_pairs=HEADER,
        intro=INTRO,
        markdown_path=SRC,
        skip_first_heading=True,
    )
    doc.save(OUT_PATH)
    print(f"Wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
