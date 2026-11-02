"""Run actual gameplay modules with minimal Roblox doubles using official Luau."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
cli = os.environ.get('LUAU_BIN', '/tmp/paintland-luau/luau')
source_dir = Path(os.environ.get('PAINTLAND_SOURCE_DIR', ROOT / 'model-source'))
modules = ['TrailMerge','Config','Grid','Trails','Movement','BotAI','CollisionSystem',
           'TerritorySystem','SpawnService','World','RegressionTests','ChunkGeometry','MinimapController','AudioCues','AudioController','AvatarThumbnails','LeaderboardService','LeaderboardController','HUDCanvas','UIController','ReviveController']
code = (ROOT / 'tests/runtime.luau').read_text()
code += '\nlocal factories, cache = {}, {}\nlocal loadModule\n'
for name in modules:
    source = (source_dir / f'{name}.luau').read_text()
    source = re.sub(r'require\(script.Parent\.(\w+)\)', r'loadModule("\1")', source)
    code += f'factories["{name}"] = function()\n{source}\nend\n'
code += '''
loadModule=function(name)
    if not cache[name] then cache[name]=factories[name]() end
    return cache[name]
end
loadModule("RegressionTests").Run(loadModule("Config"))
'''
code += (ROOT / 'tests/minimap.luau').read_text()
code += (ROOT / 'tests/audio.luau').read_text()
code += (ROOT / 'tests/trail_merge.luau').read_text()
code += (ROOT / 'tests/ui.luau').read_text()
with tempfile.TemporaryDirectory(prefix='paintland-tests-') as tmp:
    path = Path(tmp) / 'run.luau'
    path.write_text(code)
    subprocess.run([cli, str(path)], check=True)
