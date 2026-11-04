"""Verify V42 embedded sources, module references and service installation paths."""
import re
import xml.etree.ElementTree as ET
from build_model import ROOT, VERSION, SERVER_SOURCE, module_sources

sources = module_sources()
expected_modules = set(sources) - {'Paintland'}


def name(item):
    return item.find("Properties/string[@name='Name']").text


def child(parent, child_name, class_name):
    found = [c for c in parent.findall('Item') if name(c) == child_name]
    assert len(found) == 1, f'Expected exactly one {child_name}'
    assert found[0].get('class') == class_name, f'Wrong class for {child_name}'
    return found[0]


def check_scripts(modules, client, server):
    embedded = {name(m): m for m in modules.findall('Item')}
    assert set(embedded) == expected_modules, 'Missing or unexpected shared module'
    for module_name, m in embedded.items():
        assert m.get('class') == 'ModuleScript', f'Not a module: {module_name}'
        source = m.find("Properties/ProtectedString[@name='Source']").text
        assert source == sources[module_name], f'Stale embedded source: {module_name}'
        for dependency in re.findall(r'require\((?:script\.Parent|Modules)\.(\w+)\)', source):
            assert dependency in expected_modules, f'{module_name} requires missing {dependency}'
    assert client.find("Properties/ProtectedString[@name='Source']").text == sources['Paintland']
    assert server.find("Properties/ProtectedString[@name='Source']").text == SERVER_SOURCE
    assert server.find("Properties/token[@name='RunContext']").text == '1'
    for bootstrap in [client, server]:
        assert bootstrap.find("Properties/bool[@name='Disabled']").text == 'false'
    assert 'ReplicatedStorage:WaitForChild("PaintlandModules"' in sources['Paintland']


for extension in ['rbxlx', 'rbxmx']:
    root = ET.parse(ROOT / f'dist/Paintland_v{VERSION}.{extension}').getroot()
    referents = [i.attrib['referent'] for i in root.iter('Item')]
    assert len(referents) == len(set(referents)), 'Duplicate instance referents'
    if extension == 'rbxlx':
        replicated = child(root, 'ReplicatedStorage', 'ReplicatedStorage')
        starter = child(root, 'StarterPlayer', 'StarterPlayer')
        scripts = child(starter, 'StarterPlayerScripts', 'StarterPlayerScripts')
        server_service = child(root, 'ServerScriptService', 'ServerScriptService')
        child(root, 'Workspace', 'Workspace')
        child(root, 'Players', 'Players')
    else:
        wrapper = child(root, 'PaintlandV42', 'Folder')
        replicated = child(wrapper, 'ReplicatedStorage', 'Folder')
        scripts = child(wrapper, 'StarterPlayerScripts', 'Folder')
        server_service = child(wrapper, 'ServerScriptService', 'Folder')
    modules = child(replicated, 'PaintlandModules', 'Folder')
    client = child(scripts, 'PaintlandClient', 'LocalScript')
    server = child(server_service, 'PaintlandServer', 'Script')
    check_scripts(modules, client, server)
    assert len(list(root.iter('Item'))) == (len(expected_modules) + (10 if extension == 'rbxlx' else 7))
    print(f'PASS Paintland_v{VERSION}.{extension}: {len(expected_modules)} exact shared sources; client/server placement and dependencies verified')
