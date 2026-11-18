from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
def uid(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
sources=sorted(str(p.relative_to(root)) for p in (root/'StudyBlocks').rglob('*.swift'))
asset='StudyBlocks/Assets.xcassets'
objects=[]
def obj(name,text):objects.append(f'{uid(name)} = {{ {text} }};')
for path in sources:
 obj('ref'+path,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = SOURCE_ROOT;')
 obj('build'+path,f'isa = PBXBuildFile; fileRef = {uid("ref"+path)};')
obj('assets',f'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = "{asset}"; sourceTree = SOURCE_ROOT;')
obj('buildassets',f'isa = PBXBuildFile; fileRef = {uid("assets")};')
obj('app','isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "StudyBlocks.app"; sourceTree = BUILT_PRODUCTS_DIR;')
obj('main',f'isa = PBXGroup; children = ({uid("sourcegroup")}, {uid("products")}); sourceTree = "<group>";')
obj('sourcegroup','isa = PBXGroup; name = StudyBlocks; children = ('+', '.join(uid('ref'+p) for p in sources)+f', {uid("assets")}); sourceTree = "<group>";')
obj('products',f'isa = PBXGroup; name = Products; children = ({uid("app")}); sourceTree = "<group>";')
obj('sources','isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ('+', '.join(uid('build'+p) for p in sources)+'); runOnlyForDeploymentPostprocessing = 0;')
obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({uid("buildassets")}); runOnlyForDeploymentPostprocessing = 0;')
obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({uid("sources")}, {uid("frameworks")}, {uid("resources")}); buildRules = (); dependencies = (); name = StudyBlocks; productName = StudyBlocks; productReference = {uid("app")}; productType = "com.apple.product-type.application";')
obj('project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; TargetAttributes = {{ {uid("target")} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ko; hasScannedForEncodings = 0; knownRegions = (ko, en, Base); mainGroup = {uid("main")}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target")});')
for mode in ['Debug','Release']:
 project={'CLANG_ENABLE_MODULES':'YES','MACOSX_DEPLOYMENT_TARGET':'14.0','SDKROOT':'macosx','SWIFT_VERSION':'5.0','CLANG_ENABLE_OBJC_ARC':'YES','SWIFT_OPTIMIZATION_LEVEL':'"-Onone"' if mode=='Debug' else '"-O"','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else '"dwarf-with-dsym"','ENABLE_TESTABILITY':'YES' if mode=='Debug' else 'NO'}
 if mode=='Debug':project['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='"DEBUG $(inherited)"'
 target={'PRODUCT_BUNDLE_IDENTIFIER':'com.pastelj.studyblocks','PRODUCT_NAME':'"$(TARGET_NAME)"','MARKETING_VERSION':'1.1.1','CURRENT_PROJECT_VERSION':'3','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_KEY_CFBundleDisplayName':'"공부 블록"','INFOPLIST_KEY_LSApplicationCategoryType':'"public.app-category.education"','INFOPLIST_KEY_NSPrincipalClass':'NSApplication','CODE_SIGN_STYLE':'Manual','CODE_SIGN_IDENTITY':'"-"','ENABLE_HARDENED_RUNTIME':'YES','ENABLE_APP_SANDBOX':'NO','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','COMBINE_HIDPI_IMAGES':'YES','SWIFT_EMIT_LOC_STRINGS':'YES'}
 for prefix,settings in [('project',project),('target',target)]:obj(prefix+mode,'isa = XCBuildConfiguration; buildSettings = {'+' '.join(f'{k} = {v};' for k,v in settings.items())+f'}}; name = {mode};')
for prefix in ['project','target']:obj(prefix+'configs',f'isa = XCConfigurationList; buildConfigurations = ({uid(prefix+"Debug")}, {uid(prefix+"Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
(root/'StudyBlocks.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {uid("project")}; }}\n')
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="StudyBlocks.app" BlueprintName="StudyBlocks" ReferencedContainer="container:StudyBlocks.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"/>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="StudyBlocks.app" BlueprintName="StudyBlocks" ReferencedContainer="container:StudyBlocks.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="StudyBlocks.app" BlueprintName="StudyBlocks" ReferencedContainer="container:StudyBlocks.xcodeproj"/></BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(root/'StudyBlocks.xcodeproj/xcshareddata/xcschemes/StudyBlocks.xcscheme').write_text(scheme)
