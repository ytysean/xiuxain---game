import zipfile, sys
from xml.etree import ElementTree as ET

W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'

def extract(path):
    with zipfile.ZipFile(path) as z:
        xml = z.read('word/document.xml')
    root = ET.fromstring(xml)
    body = root.find(W + 'body') or root
    out = []
    for el in body.iter():
        tag = el.tag
        if tag == W + 'p':
            txt = ''.join(t.text or '' for t in el.iter(W + 't'))
            out.append(txt)
        elif tag == W + 'tr':
            cells = []
            for tc in el.findall(W + 'tc'):
                cells.append(''.join(t.text or '' for t in tc.iter(W + 't')))
            out.append(' | '.join(cells))
    return '\n'.join(out)

for p in sys.argv[1:]:
    print('\n\n========== FILE: %s ==========' % p)
    try:
        print(extract(p))
    except Exception as e:
        import traceback; traceback.print_exc()
        print('ERR', e)
