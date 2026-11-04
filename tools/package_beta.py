"""Package the current place, import model, editable source and validation scripts."""
from pathlib import Path
import zipfile
ROOT = Path(__file__).resolve().parents[1]
out = ROOT / 'dist/Paintland_v42_beta.zip'
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as archive:
    for folder in ['model-source', 'tools', 'tests']:
        for path in sorted((ROOT / folder).rglob('*')):
            if path.is_file() and '__pycache__' not in path.parts:
                archive.write(path, path.relative_to(ROOT))
    for filename in ['README.md', 'dist/Paintland_v42.rbxlx', 'dist/Paintland_v42.rbxmx',
                     'models/PaintlandClient_v26.rbxmx']:
        archive.write(ROOT / filename, filename)
print(f'Packaged {out.name}')
