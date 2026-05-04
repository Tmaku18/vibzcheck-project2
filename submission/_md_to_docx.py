"""Tiny Markdown -> python-docx converter used by the submission scripts.

Only handles the subset of Markdown actually used in the Vibzcheck
submission documents (`CURATED_QUESTIONS.md`, `BUG_LOG.md`):

    - Headings: `#`, `##`, `###`
    - Paragraphs with inline `**bold**`, `*italic*`, `` `code` ``
      and `[label](url)` links
    - Code fences ```lang ... ```
    - Bullet lists (`- `) with indented continuation lines
    - Numbered lists (`1. `, `2. `, ...) with indented continuation lines
    - Blockquotes (`> ...`) -- rendered as indented italic paragraphs
      with a colored left border
    - GFM pipe tables -- rendered as Word tables
    - Horizontal rules (`---`) -- rendered as a thin spacer

It is *not* a general-purpose Markdown engine. The goal is reproducible,
clean Word output that mirrors the source `.md` so the two formats can
never drift apart.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from docx import Document
from docx.document import Document as DocumentType
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
from docx.shared import Pt, RGBColor


# ---------------------------------------------------------------------------
# Block parsing
# ---------------------------------------------------------------------------


def _split_pipe_row(row: str) -> list[str]:
    """Split a `| col | col |` row into stripped cell strings."""
    inner = row.strip()
    if inner.startswith("|"):
        inner = inner[1:]
    if inner.endswith("|"):
        inner = inner[:-1]
    return [cell.strip() for cell in inner.split("|")]


@dataclass
class Block:
    kind: str  # heading | paragraph | bullet | number | code | rule | quote | table
    text: str = ""
    level: int = 0  # heading level OR list ordinal
    language: str = ""  # for code blocks
    # For quote blocks: list of paragraphs (already stripped of leading "> ").
    quote_paragraphs: list[str] | None = None
    # For tables: header row + body rows, each a list of cell strings.
    table_header: list[str] | None = None
    table_rows: list[list[str]] | None = None


def parse_blocks(markdown: str) -> list[Block]:
    """Split a Markdown document into a flat list of typed blocks."""
    lines = markdown.splitlines()
    blocks: list[Block] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # ---- code fence -------------------------------------------------
        if stripped.startswith("```"):
            language = stripped[3:].strip()
            i += 1
            buf: list[str] = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                buf.append(lines[i])
                i += 1
            i += 1  # consume closing fence
            blocks.append(Block("code", "\n".join(buf), language=language))
            continue

        # ---- horizontal rule -------------------------------------------
        if stripped == "---":
            blocks.append(Block("rule"))
            i += 1
            continue

        # ---- blockquote -------------------------------------------------
        if stripped.startswith(">"):
            paragraphs: list[str] = []
            buf: list[str] = []

            def flush() -> None:
                if buf:
                    paragraphs.append(" ".join(buf).strip())
                    buf.clear()

            while i < len(lines) and lines[i].lstrip().startswith(">"):
                inner = lines[i].lstrip()[1:].strip()
                if not inner:
                    flush()
                else:
                    buf.append(inner)
                i += 1
            flush()
            blocks.append(Block("quote", quote_paragraphs=paragraphs))
            continue

        # ---- pipe table -------------------------------------------------
        # Detect a header row followed by a separator like `| --- | --- |`.
        if stripped.startswith("|") and i + 1 < len(lines):
            sep = lines[i + 1].strip()
            if re.match(r"^\|?\s*:?-{3,}:?(\s*\|\s*:?-{3,}:?)*\s*\|?\s*$", sep):
                header = _split_pipe_row(stripped)
                rows: list[list[str]] = []
                i += 2  # consume header + separator
                while i < len(lines):
                    row_line = lines[i].strip()
                    if not row_line.startswith("|"):
                        break
                    rows.append(_split_pipe_row(row_line))
                    i += 1
                blocks.append(
                    Block(
                        "table",
                        table_header=header,
                        table_rows=rows,
                    )
                )
                continue

        # ---- headings --------------------------------------------------
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            level = len(m.group(1))
            blocks.append(Block("heading", m.group(2).strip(), level=level))
            i += 1
            continue

        # ---- bullet list -----------------------------------------------
        m = re.match(r"^(\s*)-\s+(.*)$", line)
        if m:
            indent = len(m.group(1))
            text_parts = [m.group(2).rstrip()]
            i += 1
            # Consume continuation lines (indented further than the bullet).
            while i < len(lines):
                cont = lines[i]
                if not cont.strip():
                    break
                if re.match(r"^(\s*)-\s+", cont):
                    break
                if re.match(r"^(\s*)\d+\.\s+", cont):
                    break
                if re.match(r"^#{1,6}\s+", cont):
                    break
                if cont.strip().startswith("```"):
                    break
                # paragraph continuation -> append (collapse leading spaces)
                text_parts.append(cont.strip())
                i += 1
            blocks.append(
                Block(
                    "bullet",
                    " ".join(text_parts).strip(),
                    level=indent // 2,
                )
            )
            continue

        # ---- numbered list ---------------------------------------------
        m = re.match(r"^(\s*)(\d+)\.\s+(.*)$", line)
        if m:
            ordinal = int(m.group(2))
            text_parts = [m.group(3).rstrip()]
            i += 1
            while i < len(lines):
                cont = lines[i]
                if not cont.strip():
                    break
                if re.match(r"^(\s*)-\s+", cont):
                    break
                if re.match(r"^(\s*)\d+\.\s+", cont):
                    break
                if re.match(r"^#{1,6}\s+", cont):
                    break
                if cont.strip().startswith("```"):
                    break
                text_parts.append(cont.strip())
                i += 1
            blocks.append(
                Block(
                    "number",
                    " ".join(text_parts).strip(),
                    level=ordinal,
                )
            )
            continue

        # ---- blank lines -> paragraph breaks ---------------------------
        if not stripped:
            i += 1
            continue

        # ---- regular paragraph -----------------------------------------
        para_lines = [stripped]
        i += 1
        while i < len(lines):
            nxt = lines[i]
            if not nxt.strip():
                break
            if re.match(r"^#{1,6}\s+", nxt):
                break
            if re.match(r"^(\s*)-\s+", nxt):
                break
            if re.match(r"^(\s*)\d+\.\s+", nxt):
                break
            if nxt.strip().startswith("```"):
                break
            if nxt.strip() == "---":
                break
            if nxt.lstrip().startswith(">"):
                break
            if nxt.lstrip().startswith("|"):
                break
            para_lines.append(nxt.strip())
            i += 1
        blocks.append(Block("paragraph", " ".join(para_lines).strip()))

    return blocks


# ---------------------------------------------------------------------------
# Inline tokenisation
# ---------------------------------------------------------------------------

# One combined regex that matches any inline construct we care about. The
# ordering of the alternatives matters: `**...**` must beat `*...*`, and
# code spans must beat everything else (no nesting allowed inside them).
_INLINE_RE = re.compile(
    r"(\*\*[^*]+\*\*)"      # bold
    r"|(`[^`]+`)"           # inline code
    r"|(\[[^\]]+\]\([^)]+\))"  # markdown link
    r"|(\*[^*]+\*)"         # italic (must come last)
)


@dataclass
class InlineRun:
    text: str
    bold: bool = False
    italic: bool = False
    code: bool = False
    link: str | None = None


def parse_inline(text: str) -> list[InlineRun]:
    """Walk an inline string, splitting it into typed text runs."""
    runs: list[InlineRun] = []
    cursor = 0
    for match in _INLINE_RE.finditer(text):
        start, end = match.span()
        if start > cursor:
            runs.append(InlineRun(text[cursor:start]))
        token = match.group(0)
        if token.startswith("**"):
            runs.append(InlineRun(token[2:-2], bold=True))
        elif token.startswith("`"):
            runs.append(InlineRun(token[1:-1], code=True))
        elif token.startswith("["):
            label_match = re.match(r"\[([^\]]+)\]\(([^)]+)\)", token)
            assert label_match is not None
            runs.append(InlineRun(label_match.group(1), link=label_match.group(2)))
        else:  # *italic*
            runs.append(InlineRun(token[1:-1], italic=True))
        cursor = end
    if cursor < len(text):
        runs.append(InlineRun(text[cursor:]))
    return runs


# ---------------------------------------------------------------------------
# Word rendering
# ---------------------------------------------------------------------------


def _add_runs(paragraph, runs: Iterable[InlineRun]) -> None:
    for run in runs:
        if not run.text:
            continue
        r = paragraph.add_run(run.text)
        if run.bold:
            r.bold = True
        if run.italic:
            r.italic = True
        if run.code:
            r.font.name = "Consolas"
            r.font.size = Pt(10)
            # Subtle dark colour so inline code stands out from prose.
            r.font.color.rgb = RGBColor(0x33, 0x33, 0x33)
        if run.link is not None:
            r.font.color.rgb = RGBColor(0x1A, 0x4B, 0x9C)
            r.underline = True


def _add_code_block(doc: DocumentType, code: str) -> None:
    """Render a fenced code block as a single shaded paragraph."""
    para = doc.add_paragraph()
    para.paragraph_format.left_indent = Pt(12)
    para.paragraph_format.space_before = Pt(4)
    para.paragraph_format.space_after = Pt(8)

    # Light gray background so the code stands apart from prose.
    p_pr = para._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), "F2F2F2")
    p_pr.append(shd)

    # Thin left border for the "code-block" look.
    pBdr = OxmlElement("w:pBdr")
    left = OxmlElement("w:left")
    left.set(qn("w:val"), "single")
    left.set(qn("w:sz"), "12")
    left.set(qn("w:space"), "4")
    left.set(qn("w:color"), "999999")
    pBdr.append(left)
    p_pr.append(pBdr)

    run = para.add_run(code)
    run.font.name = "Consolas"
    run.font.size = Pt(9)


def _add_blockquote(doc: DocumentType, paragraphs: list[str]) -> None:
    """Render a multi-paragraph blockquote with a colored left border."""
    for idx, text in enumerate(paragraphs):
        if not text:
            continue
        para = doc.add_paragraph()
        para.paragraph_format.left_indent = Pt(18)
        para.paragraph_format.space_before = Pt(2)
        para.paragraph_format.space_after = Pt(4 if idx < len(paragraphs) - 1 else 8)

        p_pr = para._p.get_or_add_pPr()
        pBdr = OxmlElement("w:pBdr")
        left = OxmlElement("w:left")
        left.set(qn("w:val"), "single")
        left.set(qn("w:sz"), "12")
        left.set(qn("w:space"), "8")
        left.set(qn("w:color"), "5B6CB7")  # muted indigo, matches the deck
        pBdr.append(left)
        p_pr.append(pBdr)

        for run in parse_inline(text):
            r = para.add_run(run.text)
            r.italic = True  # whole quote reads as voiced speech
            if run.bold:
                r.bold = True
            if run.code:
                r.font.name = "Consolas"
                r.font.size = Pt(10)
                r.font.color.rgb = RGBColor(0x33, 0x33, 0x33)
            if run.link is not None:
                r.font.color.rgb = RGBColor(0x1A, 0x4B, 0x9C)
                r.underline = True


def _add_table(
    doc: DocumentType,
    header: list[str],
    rows: list[list[str]],
) -> None:
    """Render a GFM pipe table as a styled Word table."""
    column_count = max(len(header), max((len(r) for r in rows), default=0))
    if column_count == 0:
        return
    table = doc.add_table(rows=1 + len(rows), cols=column_count)
    try:
        table.style = "Light Grid Accent 1"
    except KeyError:
        table.style = "Table Grid"

    header_row = table.rows[0]
    for col_idx in range(column_count):
        cell = header_row.cells[col_idx]
        cell.text = ""
        para = cell.paragraphs[0]
        run = para.add_run(header[col_idx] if col_idx < len(header) else "")
        run.bold = True

    for row_idx, row in enumerate(rows, start=1):
        word_row = table.rows[row_idx]
        for col_idx in range(column_count):
            cell = word_row.cells[col_idx]
            cell.text = ""
            para = cell.paragraphs[0]
            text = row[col_idx] if col_idx < len(row) else ""
            for run in parse_inline(text):
                r = para.add_run(run.text)
                if run.bold:
                    r.bold = True
                if run.italic:
                    r.italic = True
                if run.code:
                    r.font.name = "Consolas"
                    r.font.size = Pt(9)
                    r.font.color.rgb = RGBColor(0x33, 0x33, 0x33)
                if run.link is not None:
                    r.font.color.rgb = RGBColor(0x1A, 0x4B, 0x9C)
                    r.underline = True


def _add_horizontal_rule(doc: DocumentType) -> None:
    para = doc.add_paragraph()
    para.paragraph_format.space_before = Pt(2)
    para.paragraph_format.space_after = Pt(2)
    p_pr = para._p.get_or_add_pPr()
    pBdr = OxmlElement("w:pBdr")
    bottom = OxmlElement("w:bottom")
    bottom.set(qn("w:val"), "single")
    bottom.set(qn("w:sz"), "6")
    bottom.set(qn("w:space"), "1")
    bottom.set(qn("w:color"), "BBBBBB")
    pBdr.append(bottom)
    p_pr.append(pBdr)


def render_blocks(doc: DocumentType, blocks: list[Block]) -> None:
    """Render parsed blocks into an existing python-docx Document."""
    for block in blocks:
        if block.kind == "heading":
            # H1 is the document title; everything else maps directly.
            level = max(1, min(block.level, 4))
            heading = doc.add_heading(level=level)
            if level == 1:
                heading.alignment = WD_ALIGN_PARAGRAPH.CENTER
            # Render inline formatting so `code` and *italic* in headings
            # come through as actual code/italic, not literal markers.
            _add_runs(heading, parse_inline(block.text))
            continue

        if block.kind == "rule":
            _add_horizontal_rule(doc)
            continue

        if block.kind == "code":
            _add_code_block(doc, block.text)
            continue

        if block.kind == "quote":
            _add_blockquote(doc, block.quote_paragraphs or [])
            continue

        if block.kind == "table":
            _add_table(doc, block.table_header or [], block.table_rows or [])
            continue

        if block.kind == "bullet":
            para = doc.add_paragraph(style="List Bullet")
            _add_runs(para, parse_inline(block.text))
            continue

        if block.kind == "number":
            para = doc.add_paragraph(style="List Number")
            _add_runs(para, parse_inline(block.text))
            continue

        # default = paragraph
        para = doc.add_paragraph()
        _add_runs(para, parse_inline(block.text))


# ---------------------------------------------------------------------------
# Top-level helpers
# ---------------------------------------------------------------------------


def build_document(
    *,
    title: str,
    header_pairs: dict[str, str],
    intro: str,
    markdown_path: Path,
    skip_first_heading: bool = True,
) -> DocumentType:
    """Construct a Word document from a markdown source file.

    Parameters
    ----------
    title:
        Document title that appears as a centered Heading 1.
    header_pairs:
        Bold-label / value pairs printed under the title (author, CRN, ...).
    intro:
        A short paragraph explaining what the document contains.
    markdown_path:
        Path to the source `.md` file. Its first H1 is dropped because
        ``title`` already covers it.
    skip_first_heading:
        If True (default), skip the first H1 in the markdown source.
    """
    doc = Document()

    style = doc.styles["Normal"]
    style.font.name = "Calibri"
    style.font.size = Pt(11)

    title_para = doc.add_heading(title, level=0)
    title_para.alignment = WD_ALIGN_PARAGRAPH.CENTER

    for label, value in header_pairs.items():
        para = doc.add_paragraph()
        run = para.add_run(f"{label}: ")
        run.bold = True
        para.add_run(value)

    if intro:
        doc.add_paragraph()
        intro_para = doc.add_paragraph()
        intro_para.add_run(intro)

    doc.add_paragraph()

    markdown = markdown_path.read_text(encoding="utf-8")
    blocks = parse_blocks(markdown)

    if skip_first_heading:
        for idx, block in enumerate(blocks):
            if block.kind == "heading" and block.level == 1:
                blocks = blocks[:idx] + blocks[idx + 1 :]
                break

    render_blocks(doc, blocks)
    return doc
