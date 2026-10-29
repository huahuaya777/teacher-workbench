from django import template
from django.utils.html import format_html, format_html_join

from workbench.export import math_tokens, segments

register = template.Library()


def _render_math(value):
    parts = []
    for token in math_tokens(value):
        if token[0] == "sup":
            parts.append(format_html("{}<sup>{}</sup>", _render_math(token[1]), _render_math(token[2])))
        elif token[0] == "sub":
            parts.append(format_html("{}<sub>{}</sub>", _render_math(token[1]), _render_math(token[2])))
        elif token[0] == "subsup":
            parts.append(format_html("{}<sub>{}</sub><sup>{}</sup>",
                                     _render_math(token[1]), _render_math(token[2]), _render_math(token[3])))
        elif token[0] == "sqrt":
            parts.append(format_html('√<span class="math-radicand">{}</span>', _render_math(token[1])))
        elif token[0] == "frac":
            parts.append(format_html(
                '<span class="math-fraction"><span class="math-numerator">{}</span>'
                '<span class="math-denominator">{}</span></span>',
                _render_math(token[1]), _render_math(token[2]),
            ))
        else:
            parts.append(format_html("{}", token[1]))
    return format_html_join("", "{}", ((part,) for part in parts))


@register.filter
def math_segments(value):
    parts = []
    for kind, content in segments(value):
        if kind == "math":
            parts.append(format_html('<span class="math">{}</span>', _render_math(content)))
        else:
            for index, line in enumerate(content.split("\n")):
                if index:
                    parts.append(format_html("<br>"))
                parts.append(format_html("{}", line))
    return format_html_join("", "{}", ((part,) for part in parts))
