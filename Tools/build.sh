#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
xcodebuild -project StudyBlocks.xcodeproj -scheme StudyBlocks \
  -configuration Release -derivedDataPath build/DerivedData \
  -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
/usr/bin/ditto build/DerivedData/Build/Products/Release/StudyBlocks.app build/StudyBlocks.app
/usr/bin/codesign --verify --deep --strict build/StudyBlocks.app
/usr/bin/ditto -c -k --keepParent build/StudyBlocks.app build/StudyBlocks-macOS.zip
print '앱: build/StudyBlocks.app'
