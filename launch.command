#!/bin/sh
# Double-click in Finder. The application handles USB discovery and route loading.
set -eu

launcher_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)

for app_path in "$launcher_dir/Route Studio.app" "$launcher_dir/dist/Route Studio.app" "$launcher_dir/../Route Studio.app"; do
    if [ -d "$app_path" ] && [ -x "$app_path/Contents/MacOS/RouteStudio" ]; then
        exec /usr/bin/open "$app_path"
    fi
done

printf '%s\n' '未找到 Route Studio.app。' '请先完整解压安装包，将本入口与 Route Studio.app 放在同一文件夹，再双击打开。' >&2
exit 1
