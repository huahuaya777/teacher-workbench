"""Build a fictional answer sheet for visual QA of editable math export."""

from pathlib import Path

from workbench.export import render_docx


content = {
    "title": "虚构数学练习",
    "questions": [{
        "stem": r"求 [[math:y=(x-2)^2+1]] 的值。",
        "answer": (r"由 y_0=\frac{h_0-H}{d^2}，且 [[math]H_{\text{min}} \leq y_1]]，"
                   r"所以 \sqrt{\frac{d^2}{4}}=1。"),
        "source": "虚构样例",
        "ai_generated": True,
    }],
}

output = Path("data/qa/teacher-answer-math.docx")
output.parent.mkdir(parents=True, exist_ok=True)
output.write_bytes(render_docx(content, "fictional.docx", teacher=True).getvalue())
print(output)
