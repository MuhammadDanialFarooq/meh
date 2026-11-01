"""Verify the packaged model changes only the intended script sources."""
from pathlib import Path
import xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[1]
a = ET.parse(ROOT / 'models/PaintlandClient_v26.rbxmx').getroot()
b = ET.parse(ROOT / 'dist/PaintlandClient_v27.rbxmx').getroot()
changed = []
for old, new in zip(a.iter('Item'), b.iter('Item'), strict=True):
    op, np = old.find('Properties'), new.find('Properties')
    if op is None:
        continue
    os, ns = op.find("ProtectedString[@name='Source']"), np.find("ProtectedString[@name='Source']")
    if os is not None:
        name = op.find("string[@name='Name']").text
        assert ns.text == (ROOT / 'model-source' / f'{name}.luau').read_text()
        if os.text != ns.text:
            changed.append(name)
        os.text = ns.text = 'SOURCE'
assert ET.tostring(a) == ET.tostring(b), 'Non-source model data changed'
assert set(changed) == {'Config','Grid','MinimapController','RegressionTests','TerritorySystem','World'}
print('PASS: 39 script sources round-trip; only 6 intended scripts changed; model hierarchy preserved')
