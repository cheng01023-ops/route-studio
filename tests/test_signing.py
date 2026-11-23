"""Signing orchestration without running any UI, GPS or real code signing."""
from pathlib import Path
import os
import stat
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.signing import clean_finder_metadata, sign_bundle


class FinderMetadataTests(unittest.TestCase):
    def test_only_finder_attributes_are_deleted(self):
        commands = []

        def runner(command, **kwargs):
            commands.append(command)
            return subprocess.CompletedProcess(command, 0, stdout='\n'.join((
                '/tmp/Fixture.app: com.apple.FinderInfo: data',
                '/tmp/Fixture.app/Contents: com.apple.ResourceFork: data',
                '/tmp/Fixture.app: com.apple.quarantine: retained',
                '/tmp/Fixture.app: com.apple.provenance: retained',
            )))

        clean_finder_metadata(Path('/tmp/Fixture.app'), runner=runner)
        self.assertEqual([command[3] for command in commands[1:]],
                         ['com.apple.FinderInfo', 'com.apple.ResourceFork'])
        self.assertTrue(all(command[1:3] == ['-s', '-d'] for command in commands[1:]))


@unittest.skipUnless(sys.platform == 'darwin', 'ditto and macOS extended attributes')
class SigningTests(unittest.TestCase):
    def setUp(self):
        fixtures = ROOT / 'build' / 'test-fixtures'
        fixtures.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=fixtures)
        self.bundle = Path(self.temporary.name) / 'Fixture.app'
        self.executable = self.bundle / 'Contents/MacOS/Fixture'
        self.executable.parent.mkdir(parents=True)
        self.executable.write_bytes(b'original executable')
        self.executable.chmod(0o751)
        framework = self.bundle / 'Contents/Frameworks/Example.framework'
        (framework / 'Versions/A').mkdir(parents=True)
        (framework / 'Versions/A/Example').write_bytes(b'framework')
        (framework / 'Versions/Current').symlink_to('A')
        (framework / 'Example').symlink_to('Versions/Current/Example')

    def tearDown(self):
        self.temporary.cleanup()

    def test_external_staging_preserves_modes_symlinks_and_other_metadata(self):
        subprocess.run(['/usr/bin/xattr', '-w', 'com.route-studio.fixture', 'retained', str(self.bundle)], check=True)
        subprocess.run(['/usr/bin/xattr', '-w', 'com.apple.ResourceFork', 'finder fork', str(self.executable)], check=True)
        commands, stages = [], []

        def runner(command, **kwargs):
            commands.append(command)
            if command[0] != '/usr/bin/codesign':
                return subprocess.run(command, **kwargs)
            target = Path(command[-1])
            if '--force' in command:
                stages.append(target)
                self.assertEqual(target.parent.parent, Path('/private/tmp'))
                self.assertNotEqual(target, self.bundle)
                listing = subprocess.run(['/usr/bin/xattr', '-l', '-r', str(target)],
                                         check=True, capture_output=True, text=True).stdout
                self.assertNotIn('com.apple.ResourceFork', listing)
                self.assertNotIn('com.apple.FinderInfo', listing)
                self.assertIn('com.route-studio.fixture', listing)
                (target / 'Contents/MacOS/Fixture').write_bytes(b'signed executable')
                signature = target / 'Contents/_CodeSignature/CodeResources'
                signature.parent.mkdir()
                signature.write_bytes(b'signature')
            return subprocess.CompletedProcess(command, 0)

        sign_bundle(self.bundle, runner=runner)
        self.assertEqual(self.executable.read_bytes(), b'signed executable')
        self.assertEqual(stat.S_IMODE(self.executable.stat().st_mode), 0o751)
        self.assertEqual(os.readlink(self.bundle / 'Contents/Frameworks/Example.framework/Versions/Current'), 'A')
        self.assertEqual(os.readlink(self.bundle / 'Contents/Frameworks/Example.framework/Example'), 'Versions/Current/Example')
        self.assertEqual((self.bundle / 'Contents/_CodeSignature/CodeResources').read_bytes(), b'signature')
        retained = subprocess.run(['/usr/bin/xattr', '-p', 'com.route-studio.fixture', str(self.bundle)],
                                  check=True, capture_output=True, text=True).stdout.strip()
        self.assertEqual(retained, 'retained')
        signing = [command for command in commands if command[0] == '/usr/bin/codesign']
        self.assertIn('--strict', signing[1])
        self.assertNotIn('--strict', signing[-1])
        self.assertEqual(signing[-1][-1], str(self.bundle))
        self.assertFalse(stages[0].parent.exists())

    def test_signing_or_strict_verification_failure_leaves_original_intact(self):
        for failure in ('--force', '--strict'):
            with self.subTest(failure=failure):
                stages = []

                def runner(command, **kwargs):
                    if command[0] != '/usr/bin/codesign':
                        return subprocess.run(command, **kwargs)
                    staged = Path(command[-1])
                    stages.append(staged)
                    (staged / 'Contents/MacOS/Fixture').write_bytes(b'changed staged copy')
                    if failure in command:
                        raise subprocess.CalledProcessError(1, command)
                    return subprocess.CompletedProcess(command, 0)

                with self.assertRaises(subprocess.CalledProcessError):
                    sign_bundle(self.bundle, deep=False, runner=runner)
                self.assertEqual(self.executable.read_bytes(), b'original executable')
                self.assertFalse(stages[0].parent.exists())


if __name__ == '__main__':
    unittest.main()
