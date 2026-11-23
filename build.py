#!/usr/bin/env python3
"""Build a relocatable arm64 .app with a bundled Python bridge."""
import os
import pathlib
import plistlib
import shutil
import subprocess
import sys
from tools.signing import sign_bundle

ROOT = pathlib.Path(__file__).resolve().parent
BUILD = pathlib.Path(os.environ.get('ROUTE_STUDIO_BUILD', str(ROOT / 'build'))).expanduser().resolve()
DEST = pathlib.Path(os.environ.get('ROUTE_STUDIO_OUTPUT', str(ROOT / 'dist'))).expanduser().resolve()
# Keep the venv interpreter symlink path: resolving it can lose its environment.
PYTHON = pathlib.Path(os.environ.get('ROUTE_STUDIO_PYTHON', str(BUILD / '.venv' / 'bin' / 'python'))).expanduser().absolute()
APP = DEST / 'Route Studio.app'
ICON = ROOT / 'Resources' / 'AppIcon.icns'

if not ICON.is_file():
    raise FileNotFoundError(f'App icon resource is missing: {ICON}')
BUILD.mkdir(parents=True, exist_ok=True)
DEST.mkdir(parents=True, exist_ok=True)

def run(*args):
    subprocess.run([str(a) for a in args], check=True, cwd=ROOT)

if not PYTHON.exists():
    BUILD.mkdir(parents=True, exist_ok=True)
    run(sys.executable, '-m', 'venv', BUILD / '.venv')
    run(PYTHON, '-m', 'pip', 'install', '-r', ROOT / ('requirements-lock.txt' if (ROOT / 'requirements-lock.txt').exists() else 'requirements.txt'))

run(PYTHON, '-m', 'unittest', 'discover', '-s', ROOT / 'tests', '-v')
run('xcrun', 'swiftc', '-swift-version', '5', ROOT / 'Sources' / 'Models.swift', ROOT / 'Sources' / 'Coordinates.swift', ROOT / 'tests' / 'ModelsTests.swift', '-o', BUILD / 'models-tests', '-framework', 'MapKit', '-framework', 'CoreLocation')
run(BUILD / 'models-tests')
run('xcrun', 'swiftc', '-swift-version', '5', ROOT / 'Sources' / 'Models.swift', ROOT / 'Sources' / 'Coordinates.swift', ROOT / 'Sources' / 'StudioModel.swift', ROOT / 'tests' / 'StartupTests.swift', '-o', BUILD / 'startup-tests', '-framework', 'AppKit', '-framework', 'MapKit', '-framework', 'CoreLocation')
run(BUILD / 'startup-tests')
run(PYTHON, '-m', 'PyInstaller', '--noconfirm', '--clean', '--name', 'RouteBridge', '--onedir',
    '--distpath', BUILD / 'dist', '--workpath', BUILD / 'pyinstaller', '--specpath', BUILD,
    '--recursive-copy-metadata', 'pymobiledevice3',
    '--collect-data', 'pymobiledevice3', '--collect-data', 'developer_disk_image',
    '--hidden-import', 'pymobiledevice3.remote.rsd_tunnel', '--hidden-import', 'pymobiledevice3.services.cryptexd',
    '--hidden-import', 'pymobiledevice3.remote.userspace_tunnel', '--hidden-import', 'pymobiledevice3.remote.native_tunnel',
    ROOT / 'backend' / 'backend.py')
run(BUILD / 'dist' / 'RouteBridge' / 'RouteBridge', '--self-check')
APP.mkdir(parents=True, exist_ok=True)
contents = APP / 'Contents'
for part in ['MacOS', 'Resources']:
    (contents / part).mkdir(parents=True, exist_ok=True)
shutil.copy2(ROOT / 'Resources' / 'DefaultRoute.json', contents / 'Resources' / 'DefaultRoute.json')
shutil.copy2(ICON, contents / 'Resources' / 'AppIcon.icns')
bridge = contents / 'Resources' / 'Bridge'
if bridge.exists(): shutil.rmtree(bridge)
shutil.copytree(BUILD / 'dist' / 'RouteBridge', bridge)
run('xcrun', 'swiftc', '-swift-version', '5', '-O', '-parse-as-library', '-target', 'arm64-apple-macosx15.0',
    *sorted((ROOT / 'Sources').glob('*.swift')), '-o', contents / 'MacOS' / 'RouteStudio',
    '-framework', 'SwiftUI', '-framework', 'AppKit', '-framework', 'MapKit', '-framework', 'CoreLocation')
with (contents / 'Info.plist').open('wb') as f:
    plistlib.dump(dict(CFBundleExecutable='RouteStudio', CFBundleIdentifier='local.codex.RouteStudio', CFBundleName='Route Studio',
        CFBundleDisplayName='Route Studio', CFBundlePackageType='APPL', CFBundleIconFile='AppIcon', CFBundleShortVersionString='1.1.0', CFBundleVersion='2',
        LSMinimumSystemVersion='15.0', NSHighResolutionCapable=True, NSPrincipalClass='NSApplication',
        NSAppTransportSecurity={'NSAllowsLocalNetworking': True},
        NSLocalNetworkUsageDescription='通过 USB 开发连接与您选择的 iPhone 通信。'), f)
for name in ['README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.txt', 'requirements-lock.txt']:
    path = ROOT / name
    if path.exists(): shutil.copy2(path, contents / 'Resources' / name)
run(PYTHON, ROOT / 'collect_licenses.py', contents / 'Resources' / 'Licenses')
shutil.copytree(ROOT / 'Licenses', contents / 'Resources' / 'Licenses', dirs_exist_ok=True)
sign_bundle(APP)
run(contents / 'Resources' / 'Bridge' / 'RouteBridge', '--self-check')
print('Built:', APP)
launcher = DEST / '启动定位工具.app'
launcher_contents = launcher / 'Contents'
(launcher_contents / 'MacOS').mkdir(parents=True, exist_ok=True)
(launcher_contents / 'Resources').mkdir(parents=True, exist_ok=True)
shutil.copy2(ICON, launcher_contents / 'Resources' / 'AppIcon.icns')
run('xcrun', 'swiftc', '-swift-version', '5', '-O', '-parse-as-library', '-target', 'arm64-apple-macosx15.0', ROOT / 'tools' / 'Launcher.swift', '-o', launcher_contents / 'MacOS' / 'RouteStudioLauncher', '-framework', 'AppKit')
with (launcher_contents / 'Info.plist').open('wb') as f:
    plistlib.dump(dict(CFBundleExecutable='RouteStudioLauncher', CFBundleIdentifier='local.codex.RouteStudioLauncher',
        CFBundleName='启动定位工具', CFBundleDisplayName='启动定位工具', CFBundlePackageType='APPL', CFBundleIconFile='AppIcon',
        CFBundleShortVersionString='1.0.0', CFBundleVersion='1', LSMinimumSystemVersion='15.0',
        LSUIElement=True, NSHighResolutionCapable=True, NSPrincipalClass='NSApplication'), f)
sign_bundle(launcher, deep=False)
shutil.copyfile(ROOT / 'launch.command', DEST / '启动定位工具.command')
(DEST / '启动定位工具.command').chmod(0o755)
print('Built launcher:', launcher)
