"""Package a public, self-contained Mac release from a repository checkout."""
from pathlib import Path
import os
import plistlib
import shutil
import stat
import subprocess
import tempfile
import zipfile
from tools.signing import sign_bundle

ROOT = Path(__file__).resolve().parent
BUILD = Path(os.environ.get('ROUTE_STUDIO_BUILD', str(ROOT / 'build'))).expanduser().resolve()
OUTPUT = Path(os.environ.get('ROUTE_STUDIO_OUTPUT', str(ROOT / 'dist'))).expanduser().resolve()

# This allowlist also works in a source ZIP without .git. Generated folders,
# local settings, old session records and files outside the checkout stay out.
SOURCE_PATHS = (
    'Sources', 'backend', 'tests', 'Resources', 'Licenses', 'tools', 'docs',
    'examples', '.github', 'README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.txt',
    'requirements.txt', 'requirements-lock.txt', 'build.py', 'package_release.py',
    'collect_licenses.py', 'launch.command', '.gitignore', '.gitattributes',
    'CONTRIBUTING.md', 'SECURITY.md', 'CHANGELOG.md', 'RELEASE_NOTES.md', 'CODE_OF_CONDUCT.md',
)
EXCLUDED_PARTS = {'.git', '.venv', 'venv', 'build', 'dist', '__pycache__',
                  '.pytest_cache', '.mypy_cache', '.ruff_cache', '.DS_Store'}
LOCAL_ONLY_FILES = {'验证记录.txt', '复旦智慧体育学生端操作说明.pdf', '文件清单与校验.json'}


def source_files(root):
    """Only reviewed source inputs; never follow a source symlink externally."""
    for name in SOURCE_PATHS:
        base = root / name
        if base.is_symlink() or not base.exists():
            continue
        candidates = base.rglob('*') if base.is_dir() else [base]
        for path in candidates:
            relative = path.relative_to(root)
            if (path.is_symlink() or not path.is_file()
                    or EXCLUDED_PARTS.intersection(relative.parts)
                    or path.name in LOCAL_ONLY_FILES
                    or path.suffix in {'.pyc', '.pyo'}
                    or path.name.startswith('._')
                    or (path.name.startswith('.env') and path.name != '.env.example')):
                continue
            yield path


def make_source_zip(root, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source_files(root)):
            archive.write(path, Path('RouteStudio-source') / path.relative_to(root))


def copy_file(source, destination):
    Path(destination).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    shutil.copymode(source, destination)
    return destination


def make_release_zip(release, destination):
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(release.rglob('*')):
            relative = Path('Route Studio') / path.relative_to(release)
            if path.is_symlink():
                entry = zipfile.ZipInfo(str(relative))
                entry.create_system = 3
                entry.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(entry, os.readlink(path).encode('utf-8'))
            elif path.is_file():
                archive.write(path, relative)


def main():
    icon = ROOT / 'Resources' / 'AppIcon.icns'
    if not icon.is_file():
        raise FileNotFoundError(f'App icon resource is missing: {icon}')
    bundle_names = ('Route Studio.app', '启动定位工具.app')
    for name in bundle_names:
        if not (OUTPUT / name).is_dir():
            raise FileNotFoundError(f'Built app is missing: {OUTPUT / name}. Run python3 build.py first.')
    BUILD.mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source_zip = OUTPUT / 'RouteStudio-source.zip'
    make_source_zip(ROOT, source_zip)

    # A fresh staging directory avoids accidentally shipping stale local files.
    with tempfile.TemporaryDirectory(prefix='release-', dir=BUILD) as temporary:
        release = Path(temporary)
        app, launcher = [release / name for name in bundle_names]
        for bundle in (app, launcher):
            shutil.copytree(OUTPUT / bundle.name, bundle, symlinks=True, copy_function=copy_file)
        copy_file(ROOT / 'README.md', app / 'Contents/Resources/README.md')
        copy_file(ROOT / 'Resources/DefaultRoute.json', app / 'Contents/Resources/DefaultRoute.json')
        shutil.copytree(ROOT / 'Licenses', app / 'Contents/Resources/Licenses',
                        dirs_exist_ok=True, copy_function=copy_file)
        copy_file(ROOT / 'THIRD_PARTY_NOTICES.txt', app / 'Contents/Resources/THIRD_PARTY_NOTICES.txt')
        for bundle in (app, launcher):
            resources = bundle / 'Contents/Resources'
            resources.mkdir(parents=True, exist_ok=True)
            copy_file(icon, resources / 'AppIcon.icns')
            info_path = bundle / 'Contents/Info.plist'
            info = plistlib.loads(info_path.read_bytes())
            info['CFBundleIconFile'] = 'AppIcon'
            info_path.write_bytes(plistlib.dumps(info))
        sign_bundle(app)
        sign_bundle(launcher, deep=False)
        subprocess.run([str(app / 'Contents/Resources/Bridge/RouteBridge'), '--self-check'], check=True)

        copy_file(ROOT / 'launch.command', release / '启动定位工具.command')
        (release / '启动定位工具.command').chmod(0o755)
        copy_file(source_zip, release / source_zip.name)
        for name in ('README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.txt'):
            copy_file(ROOT / name, release / name)
        # Docs/examples live in the repository, never in its parent directory.
        for folder in ('docs', 'examples'):
            for path in source_files(ROOT):
                relative = path.relative_to(ROOT)
                if relative.parts[0] == folder:
                    target = release / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    copy_file(path, target)
        for source, name in ((ROOT / 'Resources/AppIcon-master.png', '定位工具图标.png'),
                             (ROOT / 'Resources/ICON-DESIGN.txt', '图标设计说明.txt')):
            if source.is_file():
                copy_file(source, release / name)
        destination = OUTPUT / 'RouteStudio-Mac.zip'
        make_release_zip(release, destination)
    with zipfile.ZipFile(destination) as archive:
        bad = archive.testzip()
        if bad is not None:
            raise RuntimeError(f'Release archive integrity check failed: {bad}')
    print('Release archive:', destination, 'bytes:', destination.stat().st_size)


if __name__ == '__main__':
    main()
