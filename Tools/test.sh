#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
swift test --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security
probe="$PWD/.build/out/Products/Debug/PersistenceProbe"
if [[ ! -x "$probe" ]]; then
  probe="$PWD/.build/debug/PersistenceProbe"
fi
folder=$(mktemp -d "$PWD/build/persistence.XXXXXX")
"$probe" write "$folder/Study.store"
"$probe" read "$folder/Study.store"
