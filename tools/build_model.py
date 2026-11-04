"""Build V42 as an openable place and a service-organized import model.

Only source files in model-source are embedded. Uploaded reference places are
never copied wholesale into the generated game.
"""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
VERSION = 42
SERVER_SOURCE = '''-- Paintland V42 server bootstrap. Install under ServerScriptService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local modules = ReplicatedStorage:WaitForChild("PaintlandModules", 15)
assert(modules, "Install PaintlandModules in ReplicatedStorage")
local Config = require(modules:WaitForChild("Config"))
if Config.MultiplayerEnabled ~= false then
    Players.CharacterAutoLoads = false
    local ok, err = xpcall(function()
        require(modules:WaitForChild("MultiplayerServer")).Start(Config)
    end, debug.traceback)
    if not ok then
        warn("[Paintland V42] Server startup failed: " .. tostring(err))
        ReplicatedStorage:SetAttribute("PaintlandServerError", tostring(err))
    end
end
'''


def property_value(properties, kind, name, value):
    child = ET.SubElement(properties, kind, name=name)
    child.text = str(value).lower() if isinstance(value, bool) else str(value)
    return child


def item(parent, class_name, name, referent, source=None):
    obj = ET.SubElement(parent, 'Item', {'class': class_name, 'referent': referent})
    props = ET.SubElement(obj, 'Properties')
    property_value(props, 'string', 'Name', name)
    if source is not None:
        property_value(props, 'ProtectedString', 'Source', source)
        if class_name in {'Script', 'LocalScript'}:
            property_value(props, 'bool', 'Disabled', False)
    return obj


def document():
    root = ET.Element('roblox', version='4')
    ET.SubElement(root, 'External').text = 'null'
    ET.SubElement(root, 'External').text = 'nil'
    return root


def module_sources():
    files = sorted((ROOT / 'model-source').glob('*.luau'))
    sources = {p.stem: p.read_text() for p in files}
    assert 'Paintland' in sources, 'Client bootstrap missing'
    for required in ['Config', 'GameLoader', 'MultiplayerServer', 'MultiplayerClient',
                     'MatchmakingUI', 'ResultsScreen', 'ReviveHeart', 'SlimeVisuals',
                     'CurrencyService', 'WalletHUD', 'Splash', 'Dash', 'AbilityRegistry',
                     'AbilityService', 'AbilityHUD']:
        assert required in sources, f'Required V42 module missing: {required}'
    return sources


def populate(replicated, client_parent, server_parent, sources):
    modules = item(replicated, 'Folder', 'PaintlandModules', 'RBXPaintlandModules')
    for name, source in sources.items():
        if name != 'Paintland':
            item(modules, 'ModuleScript', name, 'RBXModule' + name, source)
    item(client_parent, 'LocalScript', 'PaintlandClient', 'RBXPaintlandClient', sources['Paintland'])
    server = item(server_parent, 'Script', 'PaintlandServer', 'RBXPaintlandServer', SERVER_SOURCE)
    property_value(server.find('Properties'), 'token', 'RunContext', 1)


def build():
    sources = module_sources()
    out = ROOT / 'dist'
    out.mkdir(exist_ok=True)
    place = document()
    workspace = item(place, 'Workspace', 'Workspace', 'RBXWorkspace')
    camera = item(workspace, 'Camera', 'Camera', 'RBXCamera')
    property_value(workspace.find('Properties'), 'Ref', 'CurrentCamera', camera.attrib['referent'])
    players = item(place, 'Players', 'Players', 'RBXPlayers')
    property_value(players.find('Properties'), 'bool', 'CharacterAutoLoads', False)
    replicated = item(place, 'ReplicatedStorage', 'ReplicatedStorage', 'RBXReplicatedStorage')
    starter = item(place, 'StarterPlayer', 'StarterPlayer', 'RBXStarterPlayer')
    scripts = item(starter, 'StarterPlayerScripts', 'StarterPlayerScripts', 'RBXStarterPlayerScripts')
    server = item(place, 'ServerScriptService', 'ServerScriptService', 'RBXServerScriptService')
    populate(replicated, scripts, server, sources)
    model = document()
    wrapper = item(model, 'Folder', 'PaintlandV42', 'RBXPaintlandV42')
    replicated = item(wrapper, 'Folder', 'ReplicatedStorage', 'RBXInstallReplicatedStorage')
    scripts = item(wrapper, 'Folder', 'StarterPlayerScripts', 'RBXInstallStarterPlayerScripts')
    server = item(wrapper, 'Folder', 'ServerScriptService', 'RBXInstallServerScriptService')
    populate(replicated, scripts, server, sources)
    for root, extension in [(place, 'rbxlx'), (model, 'rbxmx')]:
        target = out / f'Paintland_v{VERSION}.{extension}'
        ET.ElementTree(root).write(target, encoding='utf-8', xml_declaration=True)
        print(f'Built {target.name}: {len(sources) - 1} shared modules + client/server bootstraps')


if __name__ == '__main__':
    build()
