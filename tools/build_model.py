"""Replace only script sources in the supplied Roblox XML model."""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
tree = ET.parse(ROOT / 'models/PaintlandClient_v26.rbxmx')
names = set()
for item in tree.getroot().iter('Item'):
    props = item.find('Properties')
    if props is None:
        continue
    source = props.find("ProtectedString[@name='Source']")
    if source is None:
        continue
    name = props.find("string[@name='Name']").text
    assert name not in names, f'Duplicate script: {name}'
    names.add(name)
    source.text = (ROOT / 'model-source' / f'{name}.luau').read_text()
assert names == {p.stem for p in (ROOT / 'model-source').glob('*.luau')}
out = ROOT / 'dist/PaintlandClient_v27.rbxmx'
out.parent.mkdir(exist_ok=True)
tree.write(out, encoding='utf-8', xml_declaration=True)
print(f'Built {out.name}: {len(names)} scripts')
