#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
rm -rf build/StudyBlocks.app build/StudyBlocks-macOS.zip
xcodebuild -project StudyBlocks.xcodeproj -scheme StudyBlocks \
  -configuration Release -derivedDataPath build/DerivedData \
  -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' build
/usr/bin/ditto build/DerivedData/Build/Products/Release/StudyBlocks.app build/StudyBlocks.app
/usr/bin/codesign --verify --deep --strict build/StudyBlocks.app
/usr/bin/ditto -c -k --keepParent build/StudyBlocks.app build/StudyBlocks-macOS.zip
mkdir -p Downloads
cp -f build/StudyBlocks-macOS.zip Downloads/StudyBlocks-macOS.zip
print '앱: build/StudyBlocks.app'
print '패키지: build/StudyBlocks-macOS.zip (Downloads/StudyBlocks-macOS.zip 동기화됨)'
