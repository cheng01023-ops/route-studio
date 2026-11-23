"""Keep installed dependency license notices in the delivered application."""
import importlib.metadata
from pathlib import Path
import shutil
import sys

target = Path(sys.argv[1])
target.mkdir(parents=True, exist_ok=True)
for dist in importlib.metadata.distributions():
    name = dist.metadata.get('Name', 'unknown')
    folder = target / name
    folder.mkdir(exist_ok=True)
    info = f"{name} {dist.version}\nLicense: {dist.metadata.get('License-Expression') or dist.metadata.get('License', '')}\n"
    info += '\n'.join(dist.metadata.get_all('Project-URL') or [])
    (folder / 'PACKAGE.txt').write_text(info)
    for item in dist.files or []:
        if any(token in item.name.lower() for token in ('license', 'copying', 'notice')):
            source = Path(dist.locate_file(item))
            if source.is_file():
                destination = folder / item.name
                if not destination.exists(): shutil.copy2(source, destination)
