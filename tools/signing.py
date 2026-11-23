"""Sign fresh build products outside FileProvider/iCloud synchronized folders.

Only FinderInfo and ResourceFork are removed from the temporary copy. ditto
preserves permissions, symlinks and other extended attributes, including security
metadata. No quarantine or provenance attributes are deleted.
"""
from pathlib import Path
import subprocess
import tempfile


FINDER_ATTRIBUTES = ('com.apple.FinderInfo', 'com.apple.ResourceFork')
# Ignore TMPDIR: callers can have it pointed into a synchronized checkout.
SIGNING_TEMP = Path('/private/tmp')


def clean_finder_metadata(bundle, *, runner=None):
    runner = runner or subprocess.run
    # -s operates on symlinks themselves, never on a target outside the bundle.
    listing = runner(['/usr/bin/xattr', '-s', '-l', '-r', str(bundle)],
                     check=True, capture_output=True, text=True).stdout
    for line in listing.splitlines():
        for attribute in FINDER_ATTRIBUTES:
            marker = ': ' + attribute + ':'
            if marker in line:
                path = line.split(marker, 1)[0]
                runner(['/usr/bin/xattr', '-s', '-d', attribute, path], check=True)


def sign_bundle(bundle, *, deep=True, runner=None):
    """Ad-hoc sign and strictly verify a canonical copy, then copy it back.

    The original remains untouched if signing or strict verification fails.
    The final ordinary verification tolerates Finder metadata that FileProvider
    may immediately reattach in the destination directory.
    """
    runner = runner or subprocess.run
    bundle = Path(bundle).absolute()
    if bundle.is_symlink() or not bundle.is_dir():
        raise ValueError(f'Expected an app bundle directory: {bundle}')
    with tempfile.TemporaryDirectory(prefix='route-studio-sign-', dir=SIGNING_TEMP) as temporary:
        staged = Path(temporary) / bundle.name
        # Unlike copy2 on some Python builds, ditto retains all non-Finder
        # extended attributes as well as framework symlinks and executable modes.
        runner(['/usr/bin/ditto', '--rsrc', '--extattr', str(bundle), str(staged)], check=True)
        clean_finder_metadata(staged, runner=runner)
        recursive = ['--deep'] if deep else []
        runner(['/usr/bin/codesign', '--force', *recursive, '--sign', '-', str(staged)], check=True)
        runner(['/usr/bin/codesign', '--verify', *recursive, '--strict', str(staged)], check=True)
        # The canonical source has no custom Finder icon/resource-fork data.
        # ditto copies the newly signed Mach-O bytes and signature resources too.
        runner(['/usr/bin/ditto', '--rsrc', '--extattr', str(staged), str(bundle)], check=True)
        runner(['/usr/bin/codesign', '--verify', *recursive, str(bundle)], check=True)
