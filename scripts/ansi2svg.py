#!/usr/bin/env python3
# ansi2svg.py — render ANSI-colored terminal lines (a claudometer statusline) to a
# self-contained SVG that GitHub renders inline. Reads ANSI on stdin, writes SVG on stdout.
#   usage: <cmd producing ANSI> | python3 ansi2svg.py [title] > out.svg
import sys, re, html

CW, LH, PAD, FS = 9.0, 22.0, 14.0, 15          # char width, line height, padding, font-size
BG, DEFAULT_FG = "#0d1117", "#c9d1d9"          # GitHub-dark background / default fg
TITLE_FS, TITLE_H = 12, 22

BASIC = {  # 30-37 / 90-97  (a pleasant VS Code-ish palette)
 30:"#1e1e1e",31:"#f44747",32:"#4ec94e",33:"#d7ba7d",34:"#569cd6",35:"#c586c0",36:"#4ec9b0",37:"#d4d4d4",
 90:"#6e7681",91:"#f44747",92:"#4ec94e",93:"#d7ba7d",94:"#569cd6",95:"#c586c0",96:"#4ec9b0",97:"#ffffff"}
CUBE = [0,95,135,175,215,255]

def c256(n):
    if n < 16:
        return BASIC[[30,31,32,33,34,35,36,37,90,91,92,93,94,95,96,97][n]]
    if n <= 231:
        n -= 16; return "#%02x%02x%02x" % (CUBE[n//36], CUBE[(n%36)//6], CUBE[n%6])
    v = 8 + (n-232)*10; return "#%02x%02x%02x" % (v,v,v)

SGR = re.compile(r"\x1b\[([0-9;]*)m")

def apply(codes, st):
    it = iter(codes)
    for c in it:
        if c in (0, None): st.update(fg=DEFAULT_FG, bold=False, dim=False)
        elif c == 1: st["bold"] = True
        elif c == 2: st["dim"] = True
        elif c == 22: st["bold"] = st["dim"] = False
        elif c == 38:
            m = next(it, None)
            if m == 5: st["fg"] = c256(next(it, 7))
            elif m == 2: st["fg"] = "#%02x%02x%02x" % (next(it,0), next(it,0), next(it,0))
        elif c == 39: st["fg"] = DEFAULT_FG
        elif 30 <= c <= 37 or 90 <= c <= 97: st["fg"] = BASIC[c]
    return st

WIDE = set("●◐○")   # geometric circles render 2 columns wide in most mono fonts
def vwidth(txt): return sum(2 if ch in WIDE else 1 for ch in txt)

def line_to_spans(line):
    st = {"fg": DEFAULT_FG, "bold": False, "dim": False}
    spans, col, pos = [], 0, 0
    for m in SGR.finditer(line):
        txt = line[pos:m.start()]
        if txt:
            spans.append((col, txt, dict(st))); col += vwidth(txt)
        codes = [int(x) if x else 0 for x in m.group(1).split(";")] if m.group(1) else [0]
        apply(codes, st)
        pos = m.end()
    tail = line[pos:]
    if tail: spans.append((col, tail, dict(st))); col += vwidth(tail)
    return spans, col

def main():
    title = sys.argv[1] if len(sys.argv) > 1 else ""
    raw = sys.stdin.read().rstrip("\n").split("\n")
    parsed = [line_to_spans(l) for l in raw]
    cols = max([c for _, c in parsed] + [1])
    top = PAD + (TITLE_H if title else 0)
    W = round(cols*CW + 2*PAD + CW); H = round(top + len(parsed)*LH + PAD)  # +1 char slack on the right
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="ui-monospace,SFMono-Regular,Menlo,Consolas,monospace" font-size="{FS}">']
    out.append(f'<rect width="{W}" height="{H}" rx="8" fill="{BG}"/>')
    if title:
        out.append(f'<text x="{PAD}" y="{PAD+11}" font-size="{TITLE_FS}" fill="#6e7681">{html.escape(title)}</text>')
    for i, (spans, _) in enumerate(parsed):
        y = round(top + i*LH + FS)
        out.append(f'<text y="{y}" xml:space="preserve">')
        for col, txt, st in spans:
            x = round(PAD + col*CW, 1)
            style = f' font-weight="bold"' if st["bold"] else ""
            op = ' fill-opacity="0.55"' if st["dim"] else ""
            out.append(f'<tspan x="{x}" fill="{st["fg"]}"{style}{op}>{html.escape(txt)}</tspan>')
        out.append('</text>')
    out.append('</svg>')
    sys.stdout.write("\n".join(out) + "\n")

main()
