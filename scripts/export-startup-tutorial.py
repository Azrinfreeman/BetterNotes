"""Export the startup tutorial's Markdown subset without extra dependencies."""
from html import escape
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'docs/tutorial/startup-and-note-restoration.md'


def inline(text):
    text = escape(text)
    return re.sub(r'`([^`]+)`', r'<code>\1</code>', text)


def render(source):
    output, paragraph, code = [], [], None
    in_list = False

    def flush():
        if paragraph:
            output.append('<p>' + inline(' '.join(paragraph)) + '</p>')
            paragraph.clear()

    for line in source.splitlines():
        if line.startswith('```'):
            flush()
            if code is None:
                code = []
            else:
                output.append('<pre><code>' + escape('\n'.join(code)) + '</code></pre>')
                code = None
            continue
        if code is not None:
            code.append(line)
            continue
        if in_list and not line.startswith('- '):
            output.append('</ul>')
            in_list = False
        heading = re.match(r'^(#{1,3}) (.+)$', line)
        if heading:
            flush()
            level = len(heading[1])
            output.append(f'<h{level}>{inline(heading[2])}</h{level}>')
        elif line.startswith('- '):
            flush()
            if not in_list:
                output.append('<ul>')
                in_list = True
            output.append('<li>' + inline(line[2:]) + '</li>')
        elif not line.strip():
            flush()
        else:
            paragraph.append(line)
    flush()
    if in_list:
        output.append('</ul>')
    if code is not None:
        raise ValueError('Unclosed code fence')
    return '\n'.join(output)


if __name__ == '__main__':
    body = render(SOURCE.read_text(encoding='utf-8'))
    html = '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>BetterNotes — Startup and note restoration</title>
<style>
:root { color-scheme: light; font-family: "Segoe UI", sans-serif; color: #242320; background: #fff; }
body { max-width: 48rem; margin: 3rem auto; padding: 0 1.5rem; font-size: 16px; line-height: 1.6; }
h1 { font-size: 2rem; line-height: 1.2; letter-spacing: -.025em; }
h2 { font-size: 1.3rem; margin-top: 2rem; break-after: avoid; }
li { margin: .55rem 0; }
code { font-family: Consolas, monospace; font-size: .88em; overflow-wrap: anywhere; }
pre { background: #f4f3f0; padding: 1rem; white-space: pre-wrap; border-left: 3px solid #666255; }
p { margin: .9rem 0; }
footer { border-top: 1px solid #ccc; margin-top: 2rem; padding-top: 1rem; color: #555; font-size: .85rem; }
@page { size: letter; margin: .7in; }
@media print { body { margin: 0; padding: 0; max-width: none; font-size: 10pt; } pre { break-inside: avoid; } }
</style><main>''' + body + '''</main><footer>Generated from startup-and-note-restoration.md.
Regenerate with python scripts/export-startup-tutorial.py.</footer></html>'''
    target = SOURCE.with_suffix('.html')
    target.write_text(html, encoding='utf-8')
    print(target)
