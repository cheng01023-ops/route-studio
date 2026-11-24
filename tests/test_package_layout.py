"""Public checkout paths and source archives, without invoking compilers or USB."""
import ast
import importlib.util
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
spec = importlib.util.spec_from_file_location('route_studio_packaging', ROOT / 'package_release.py')
packaging = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packaging)


class PublicLayoutTests(unittest.TestCase):
    def setUp(self):
        fixtures = ROOT / 'build' / 'test-fixtures'
        fixtures.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=fixtures)
        self.root = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def write(self, relative, data='fixture'):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data)
        return path

    def config(self, overrides=None):
        self.write('Resources/AppIcon.icns')
        tree = ast.parse((ROOT / 'build.py').read_text())
        prefix = []
        for node in tree.body:
            if isinstance(node, ast.FunctionDef) and node.name == 'run':
                break
            prefix.append(node)
        namespace = {'__file__': str(self.root / 'build.py')}
        environment = {key: value for key, value in os.environ.items() if not key.startswith('ROUTE_STUDIO_')}
        environment.update(overrides or {})
        with patch.dict(os.environ, environment, clear=True):
            exec(compile(ast.Module(body=prefix, type_ignores=[]), '<build-config>', 'exec'), namespace)
        return namespace

    def test_default_build_paths_stay_inside_checkout(self):
        config = self.config()
        self.assertEqual(config['BUILD'], self.root / 'build')
        self.assertEqual(config['DEST'], self.root / 'dist')
        self.assertTrue(config['BUILD'].is_dir())
        self.assertTrue(config['DEST'].is_dir())

    def test_external_venv_keeps_symlink_path_and_creates_directories(self):
        interpreter = self.root / 'external-venv' / 'bin' / 'python'
        interpreter.parent.mkdir(parents=True)
        interpreter.symlink_to(sys.executable)
        config = self.config({'ROUTE_STUDIO_PYTHON': str(interpreter),
                              'ROUTE_STUDIO_BUILD': str(self.root / 'custom-build'),
                              'ROUTE_STUDIO_OUTPUT': str(self.root / 'custom-dist')})
        self.assertEqual(config['PYTHON'], interpreter)
        self.assertNotEqual(config['PYTHON'], interpreter.resolve())
        self.assertTrue(config['BUILD'].is_dir())
        self.assertTrue(config['DEST'].is_dir())

    def test_source_zip_excludes_local_data_and_generated_directories(self):
        self.write('README.md', 'public readme')
        self.write('Sources/App.swift', 'public code')
        self.write('docs/user-guide.md', 'public instructions')
        self.write('examples/route.json', '{}')
        self.write('Resources/DefaultRoute.json', '{}')
        self.write('.github/workflows/check.yml', 'name: checks')
        for name in ('.git/config', '.venv/secret.txt', 'build/secret.txt', 'dist/old.zip',
                     'backend/__pycache__/cached.pyc', 'backend/.env', 'docs/验证记录.txt',
                     'docs/复旦智慧体育学生端操作说明.pdf', 'private-record.txt'):
            self.write(name, 'LOCAL-ONLY')
        destination = self.root / 'dist' / 'RouteStudio-Dual-source.zip'
        packaging.make_source_zip(self.root, destination)
        with zipfile.ZipFile(destination) as archive:
            names = set(archive.namelist())
            self.assertIn('RouteStudio-Dual-source/Sources/App.swift', names)
            self.assertIn('RouteStudio-Dual-source/docs/user-guide.md', names)
            self.assertIn('RouteStudio-Dual-source/.github/workflows/check.yml', names)
            self.assertFalse(any(b'LOCAL-ONLY' in archive.read(name) for name in names))
            self.assertFalse(any('/dist/' in name or '/.git/' in name for name in names))
            self.assertIsNone(archive.testzip())

    def test_source_zip_does_not_follow_external_symlinks(self):
        self.write('README.md', 'public')
        secret = self.write('outside.txt', 'external private data')
        (self.root / 'backend').mkdir()
        (self.root / 'backend' / 'secret.py').symlink_to(secret)
        destination = self.root / 'dist' / 'RouteStudio-Dual-source.zip'
        packaging.make_source_zip(self.root, destination)
        with zipfile.ZipFile(destination) as archive:
            self.assertNotIn('RouteStudio-Dual-source/backend/secret.py', archive.namelist())

    def test_sample_generator_writes_checkout_examples(self):
        for name in ('tools/generate_test_route.py', 'backend/route_engine.py', 'backend/coordinates.py'):
            destination = self.root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, destination)
        subprocess.run([sys.executable, str(self.root / 'tools/generate_test_route.py')],
                       cwd=self.root.parent, capture_output=True, text=True, check=True, timeout=10)
        self.assertTrue((self.root / 'examples/南区田径场-1000米.json').is_file())
        self.assertTrue((self.root / 'examples/南区田径场-1000米.gpx').is_file())
        self.assertFalse((self.root / '南区田径场-1000米.json').exists())

    def test_release_uses_fresh_staging_and_public_docs(self):
        self.write('Resources/AppIcon.icns')
        self.write('Resources/DefaultRoute.json', '{}')
        self.write('README.md', 'public README')
        self.write('LICENSE', 'license fixture')
        self.write('THIRD_PARTY_NOTICES.txt', 'notices fixture')
        self.write('Licenses/example.txt', 'license')
        self.write('launch.command', '#!/bin/sh\n')
        self.write('docs/user-guide.md', 'public instructions')
        self.write('examples/route.json', '{}')
        self.write('build/release/验证记录.txt', 'old private session')
        output = self.root / 'dist'
        for name in ('Route Studio Dual.app', '双设备定位工具.app'):
            info = self.write('dist/' + name + '/Contents/Info.plist')
            info.write_bytes(plistlib.dumps({'CFBundleExecutable': 'fixture'}))
        with patch.object(packaging, 'ROOT', self.root), \
             patch.object(packaging, 'BUILD', self.root / 'build'), \
             patch.object(packaging, 'OUTPUT', output), \
             patch.object(packaging, 'sign_bundle') as sign, \
             patch.object(packaging.subprocess, 'run'):
            packaging.main()
        self.assertEqual(sign.call_count, 2)
        with zipfile.ZipFile(output / 'RouteStudio-Dual-Mac.zip') as archive:
            self.assertIn('Route Studio Dual/docs/user-guide.md', archive.namelist())
            self.assertIn('Route Studio Dual/examples/route.json', archive.namelist())
            self.assertIn('Route Studio Dual/RouteStudio-Dual-source.zip', archive.namelist())
            self.assertFalse(any('验证记录' in name for name in archive.namelist()))
        self.assertFalse(list((self.root / 'build').glob('release-*')))


if __name__ == '__main__':
    unittest.main()
