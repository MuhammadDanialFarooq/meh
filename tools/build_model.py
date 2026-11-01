"""Build the current beta, preserving the supplied model and adding audio modules."""
from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
tree = ET.parse(ROOT / 'models/PaintlandClient_v26.rbxmx')
names = set()
modules_folder = None
module_template = None
for item in tree.getroot().iter('Item'):
    props = item.find('Properties')
    if props is None:
        continue
    name = props.find("string[@name='Name']").text
    if name == 'PaintlandModules':
        modules_folder = item
    source = props.find("ProtectedString[@name='Source']")
    if source is None:
        continue
    if item.get('class') == 'ModuleScript' and module_template is None:
        module_template = deepcopy(item)
    assert name not in names, f'Duplicate script: {name}'
    names.add(name)
    source.text = (ROOT / 'model-source' / f'{name}.luau').read_text()
assert modules_folder is not None and module_template is not None
for path in sorted((ROOT / 'model-source').glob('*.luau')):
    if path.stem in names:
        continue
    assert path.stem in {'AudioCues', 'AudioController'}, f'Unexpected new module: {path.stem}'
    module = deepcopy(module_template)
    module.set('referent', 'RBXPaintlandV28' + path.stem)
    props = module.find('Properties')
    props.find("string[@name='Name']").text = path.stem
    props.find("ProtectedString[@name='Source']").text = path.read_text()
    modules_folder.append(module)
    names.add(path.stem)
assert names == {p.stem for p in (ROOT / 'model-source').glob('*.luau')}
out = ROOT / 'dist/PaintlandClient_v28.rbxmx'
out.parent.mkdir(exist_ok=True)
tree.write(out, encoding='utf-8', xml_declaration=True)
print(f'Built {out.name}: {len(names)} scripts')
