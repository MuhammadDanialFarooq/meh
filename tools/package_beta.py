"""Package the current importable model alongside editable source and tests."""
from pathlib import Path
import zipfile
ROOT = Path(__file__).resolve().parents[1]
out = ROOT / 'dist/Paintland_v37_beta.zip'
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as archive:
    for folder in ['model-source', 'tools', 'tests']:
        for path in sorted((ROOT / folder).rglob('*')):
            if path.is_file() and '__pycache__' not in path.parts:
                archive.write(path, path.relative_to(ROOT))
    for filename in ['README.md', 'dist/PaintlandClient_v37.rbxmx', 'models/PaintlandClient_v26.rbxmx']:
        archive.write(ROOT / filename, filename)
print(f'Packaged {out.name}')
