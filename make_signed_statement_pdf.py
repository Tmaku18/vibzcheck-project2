"""Generate Makuvaza_Tanaka_Vibzcheck_Project2_Signed_Statement.pdf.

Produces the signed commitment statement PDF that is required to be attached to the
Project 2 proposal (.docx) at iCollege upload time.

Run from the Project2 directory:

    python make_signed_statement_pdf.py
"""

from __future__ import annotations

try:
    from reportlab.lib.pagesizes import LETTER
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.lib.enums import TA_CENTER, TA_LEFT
    from reportlab.platypus import (
        SimpleDocTemplate,
        Paragraph,
        Spacer,
        Table,
        TableStyle,
        ListFlowable,
        ListItem,
    )
    from reportlab.lib import colors
except ImportError:
    print("Installing reportlab...")
    import subprocess
    import sys

    subprocess.check_call([sys.executable, "-m", "pip", "install", "reportlab"])
    from reportlab.lib.pagesizes import LETTER
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.lib.enums import TA_CENTER, TA_LEFT
    from reportlab.platypus import (
        SimpleDocTemplate,
        Paragraph,
        Spacer,
        Table,
        TableStyle,
        ListFlowable,
        ListItem,
    )
    from reportlab.lib import colors


STUDENT_NAME = "Tanaka Makuvaza"
STUDENT_ID = "002252191"
COURSE = "CSC 4360/6370 - Mobile App Development"
TERM = "Spring 2026"
CRN = "13598"
PROPOSAL_DATE = "April 20, 2026"
TEAM_NAME = "Vibzcheck - Solo Team (Tanaka Makuvaza)"
GITHUB_URL = "https://github.com/Tmaku18/vibzcheck-project2"
PROJECT_TITLE = "Vibzcheck - Collaborative Music App"
OUTPUT_FILENAME = "Makuvaza_Tanaka_Vibzcheck_Project2_Signed_Statement.pdf"


def build_styles():
    base = getSampleStyleSheet()
    styles = {
        "title": ParagraphStyle(
            "Title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=18,
            alignment=TA_CENTER,
            spaceAfter=4,
        ),
        "subtitle": ParagraphStyle(
            "Subtitle",
            parent=base["Normal"],
            fontName="Helvetica-Bold",
            fontSize=12,
            alignment=TA_CENTER,
            spaceAfter=2,
        ),
        "meta": ParagraphStyle(
            "Meta",
            parent=base["Normal"],
            fontSize=10,
            alignment=TA_CENTER,
            spaceAfter=2,
        ),
        "section": ParagraphStyle(
            "Section",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=13,
            spaceBefore=14,
            spaceAfter=6,
        ),
        "body": ParagraphStyle(
            "Body",
            parent=base["BodyText"],
            fontSize=10.5,
            leading=14,
            spaceAfter=6,
            alignment=TA_LEFT,
        ),
        "bullet": ParagraphStyle(
            "Bullet",
            parent=base["BodyText"],
            fontSize=10.5,
            leading=14,
            leftIndent=14,
            spaceAfter=2,
        ),
    }
    return styles


def build_kv_table(rows):
    table = Table(rows, colWidths=[1.7 * inch, 4.5 * inch])
    table.setStyle(
        TableStyle(
            [
                ("FONT", (0, 0), (-1, -1), "Helvetica", 10),
                ("FONT", (0, 0), (0, -1), "Helvetica-Bold", 10),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("BOX", (0, 0), (-1, -1), 0.5, colors.grey),
                ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.lightgrey),
                ("BACKGROUND", (0, 0), (0, -1), colors.whitesmoke),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return table


def build_signature_table():
    rows = [
        ["Member Name", STUDENT_NAME],
        ["Student ID", STUDENT_ID],
        ["Role / Responsibility", "UI / Backend / Firebase / Testing / Documentation (sole owner)"],
        ["Signature", ""],
        ["Date", ""],
    ]
    table = Table(rows, colWidths=[1.7 * inch, 4.5 * inch], rowHeights=[0.35 * inch] * 3 + [0.7 * inch, 0.45 * inch])
    table.setStyle(
        TableStyle(
            [
                ("FONT", (0, 0), (-1, -1), "Helvetica", 10),
                ("FONT", (0, 0), (0, -1), "Helvetica-Bold", 10),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("BOX", (0, 0), (-1, -1), 0.5, colors.grey),
                ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.lightgrey),
                ("BACKGROUND", (0, 0), (0, -1), colors.whitesmoke),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return table


def bullets(items, style):
    flowables = [Paragraph(text, style) for text in items]
    return ListFlowable(
        [ListItem(f, leftIndent=10) for f in flowables],
        bulletType="bullet",
        start="circle",
        leftIndent=14,
    )


def main():
    styles = build_styles()
    doc = SimpleDocTemplate(
        OUTPUT_FILENAME,
        pagesize=LETTER,
        leftMargin=0.9 * inch,
        rightMargin=0.9 * inch,
        topMargin=0.9 * inch,
        bottomMargin=0.9 * inch,
        title="Vibzcheck Project 2 - Signed Commitment Statement",
        author=STUDENT_NAME,
    )

    story = []

    story.append(Paragraph("Signed Commitment Statement", styles["title"]))
    story.append(Paragraph("Flutter and Firebase Final Group Project (Project 2)", styles["subtitle"]))
    story.append(Paragraph(f"{COURSE} | {TERM} | CRN {CRN}", styles["meta"]))
    story.append(Paragraph(f"Project: {PROJECT_TITLE}", styles["meta"]))
    story.append(Spacer(1, 14))

    story.append(Paragraph("Submission Details", styles["section"]))
    story.append(
        build_kv_table(
            [
                ["Course", COURSE],
                ["Section / CRN", CRN],
                ["Term", TERM],
                ["Project", PROJECT_TITLE],
                ["Team Name", TEAM_NAME],
                ["Proposal Date", PROPOSAL_DATE],
                ["GitHub Repository", GITHUB_URL],
                ["Degree Level", "Graduate (Master's) - includes advanced extension"],
            ]
        )
    )

    story.append(Paragraph("Statement of Commitment", styles["section"]))
    story.append(
        Paragraph(
            "By signing below, the team member listed in this document affirms each of the "
            "following commitments for Project 2 of the Mobile App Development course:",
            styles["body"],
        )
    )
    story.append(
        bullets(
            [
                "Individual contributions will be documented through frequent, granular Git "
                "commits with meaningful, descriptive messages on the public repository "
                f"<font name='Helvetica-Bold'>{GITHUB_URL}</font>.",
                "The signing team member can explain every implementation section, "
                "architectural decision, Firestore data model, and security rule used in the "
                "delivered application.",
                "Code quality, automated and manual testing, and supporting documentation will "
                "meet the standards described in the Project 2 Submission Requirements.",
                "All required Firebase services (Authentication, Cloud Firestore, Cloud "
                "Storage, Cloud Messaging, and Cloud Functions) will be implemented and "
                "demonstrated in the final build.",
                "The required AI must-solve helper and the graduate-level fairness ranking "
                "module will be implemented with transparent, defensible logic.",
                "The proposal deadline of April 20, 2026 (11:59 PM) and the final delivery "
                "deadline of May 3, 2026 (11:59 PM) are firm and will be met.",
                "Any use of AI assistance during development will be reviewed, validated, and "
                "documented by the signing team member; AI output will not be relied on without "
                "verification.",
                "This is acknowledged as a one-person team submission, and the signing member "
                "accepts full ownership of every deliverable: code, tests, documentation, "
                "wireframes, slides, demo video, and APK.",
            ],
            styles["bullet"],
        )
    )

    story.append(Paragraph("Member Acknowledgement and Signature", styles["section"]))
    story.append(
        Paragraph(
            "The team member below acknowledges and agrees to all commitments listed above and "
            "confirms full ownership of the Vibzcheck submission for Project 2.",
            styles["body"],
        )
    )
    story.append(Spacer(1, 6))
    story.append(build_signature_table())

    story.append(Spacer(1, 18))
    story.append(
        Paragraph(
            "Submission instruction reminder: this signed PDF must be attached to the proposal "
            "Word document <font name='Helvetica-Bold'>"
            "Makuvaza_Tanaka_Vibzcheck_Project2_Proposal.docx</font> and uploaded to the "
            "iCollege Dropbox by the proposal deadline.",
            styles["body"],
        )
    )

    doc.build(story)
    print(f"Wrote {OUTPUT_FILENAME}")


if __name__ == "__main__":
    main()
