#!/bin/sh
# bump-version.sh — 一键同步版本号（control / prefs Info.plist / prefs Version.h）
# 用法：sh Scripts/bump-version.sh 0.0.1-2
# 规则：首次 0.0.1-1；小改尾号 +1（0.0.1-2 → 0.0.1-3 …）；功能轮 0.0.N-1。
# 兼容 GNU sed / BSD sed（macOS）——用临时文件改写，避免 -i 差异。
set -e
new="$1"
if [ -z "$new" ]; then
    echo "用法: sh Scripts/bump-version.sh <版本，如 0.0.1-2>"
    exit 1
fi

cd "$(dirname "$0")/.."

edit() { # edit <file> <sed-script>
    tmp=$(mktemp "${TMPDIR:-/tmp}/spbump.XXXXXX")
    sed "$2" "$1" > "$tmp"
    cat "$tmp" > "$1"
    rm -f "$tmp"
}

# 1) control
edit control "s/^Version: .*/Version: $new/"

# 2) prefs/Info.plist（两个版本 string）
edit prefs/Info.plist "s#<string>[0-9][0-9.]*-[0-9][0-9]*</string>#<string>$new</string>#g"

# 3) prefs/Version.h
edit prefs/Version.h "s/#define SP_VERSION @\".*\"/#define SP_VERSION @\"$new\"/"

echo "已同步到 $new："
echo "  control          -> $(grep '^Version:' control)"
echo "  prefs/Version.h  -> $(grep SP_VERSION prefs/Version.h)"
grep -c "<string>$new</string>" prefs/Info.plist | sed 's/^/  Info.plist 命中条数: /'
echo "完成。发版：git tag v$new && git push origin --tags （Actions 自动出 Release + deb）"
