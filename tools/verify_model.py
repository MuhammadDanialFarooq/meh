"""Verify the model's original properties plus the two intended audio modules."""
from pathlib import Path
import xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[1]
a = ET.parse(ROOT / 'models/PaintlandClient_v26.rbxmx').getroot()
b = ET.parse(ROOT / 'dist/PaintlandClient_v30.rbxmx').getroot()
changed, added = set(), set()
for parent in list(b.iter('Item')):
    for item in list(parent.findall('Item')):
        props = item.find('Properties')
        if props is None:
            continue
        name = props.find("string[@name='Name']").text
        if name in {'AudioCues', 'AudioController'}:
            assert item.get('class') == 'ModuleScript'
            assert props.find("ProtectedString[@name='Source']").text == (ROOT / 'model-source' / f'{name}.luau').read_text()
            assert parent.find("Properties/string[@name='Name']").text == 'PaintlandModules'
            added.add(name)
            parent.remove(item)
for old, new in zip(a.iter('Item'), b.iter('Item'), strict=True):
    op, np = old.find('Properties'), new.find('Properties')
    if op is None:
        continue
    os, ns = op.find("ProtectedString[@name='Source']"), np.find("ProtectedString[@name='Source']")
    if os is not None:
        name = op.find("string[@name='Name']").text
        assert ns.text == (ROOT / 'model-source' / f'{name}.luau').read_text()
        if os.text != ns.text:
            changed.add(name)
        os.text = ns.text = 'SOURCE'
assert ET.tostring(a) == ET.tostring(b), 'Existing non-source model data changed'
assert changed == {'Config','Grid','MinimapController','RegressionTests','TerritorySystem','World','GameLoader','HUDCanvas','UIController','LeaderboardController','ReviveController'}
assert added == {'AudioCues', 'AudioController'}
print('PASS: 41 sources round-trip; 11 original scripts changed and 2 audio modules added; original properties preserved')
