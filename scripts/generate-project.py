#!/usr/bin/env python3
"""Generate the dependency-free Xcode project deterministically; no XcodeGen required."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects = []
def obj(name, value):
    objects.append(f'{uid(name)} = {{ {value} }};')
    return uid(name)
refs, builds = [], []
for path in sorted((root / 'Sources/SprayCanApp').glob('*.swift')):
    rel = str(path.relative_to(root))
    ref = obj(rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{rel}"; sourceTree = "<group>";')
    refs.append(ref)
    builds.append(obj('build'+rel, f'isa = PBXBuildFile; fileRef = {ref};'))
assets = obj('assets', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Resources/Assets.xcassets; sourceTree = "<group>";')
assetbuild = obj('assetbuild', f'isa = PBXBuildFile; fileRef = {assets};')
product = obj('app', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = "Spray Can.app"; sourceTree = BUILT_PRODUCTS_DIR;')
package = obj('package', 'isa = XCLocalSwiftPackageReference; relativePath = .;')
core = obj('core', f'isa = XCSwiftPackageProductDependency; package = {package}; productName = SprayCanCore;')
corebuild = obj('corebuild', f'isa = PBXBuildFile; productRef = {core};')
sources = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
resources = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({assetbuild},); runOnlyForDeploymentPostprocessing = 0;')
frameworks = obj('frameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({corebuild},); runOnlyForDeploymentPostprocessing = 0;')
products = obj('products', f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
group = obj('group', f'isa = PBXGroup; children = ({",".join(refs+[assets,products])},); sourceTree = "<group>";')
common = '''SDKROOT = macosx; MACOSX_DEPLOYMENT_TARGET = 14.0; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES;'''
app_settings = '''PRODUCT_NAME = "Spray Can"; EXECUTABLE_NAME = SprayCan; PRODUCT_BUNDLE_IDENTIFIER = io.github.Kymer0615.SprayCan; INFOPLIST_FILE = Resources/Info.plist; GENERATE_INFOPLIST_FILE = NO; CODE_SIGN_ENTITLEMENTS = Resources/SprayCan.entitlements; CODE_SIGN_STYLE = Manual; CODE_SIGN_IDENTITY = "-"; ENABLE_HARDENED_RUNTIME = YES; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; COMBINE_HIDPI_IMAGES = YES; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";'''
for owner in ['project', 'target']:
    configs = []
    for config in ['Debug','Release']:
        options = 'SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf;' if config == 'Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
        configs.append(obj(owner+config, f'isa = XCBuildConfiguration; buildSettings = {{ {common} {app_settings if owner=="target" else ""} {options} }}; name = {config};'))
    obj(owner+'configs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({sources},{frameworks},{resources},); buildRules = (); dependencies = (); name = SprayCan; packageProductDependencies = ({core},); productName = "Spray Can"; productReference = {product}; productType = "com.apple.product-type.application";')
project = obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; }}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; packageReferences = ({package},); targets = ({target},);')
(root/'SprayCan.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n')
(root/'SprayCan.xcodeproj/xcshareddata/xcschemes/SprayCan.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Spray Can.app" BlueprintName="SprayCan" ReferencedContainer="container:SprayCan.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Spray Can.app" BlueprintName="SprayCan" ReferencedContainer="container:SprayCan.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
