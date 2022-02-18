$ErrorActionPreference = "Stop"

$ZigSrcDir          = Resolve-Path . # Resolve-Path $PSScriptRoot
$ZigTarget          = "x86_64-windows-gnu"
$ZigDevKitName      = "zig+llvm+lld+clang-$ZigTarget-0.9.1"
$ZigDevKitURL       = "https://ziglang.org/deps/$ZigDevKitName.zip"
$ZigDevKitPrefix    = Resolve-Path "$ZigSrcDir/../$ZigDevKitName"
# master build.zig might be too new use devkits
if (-not (Test-Path "$ZigSrcDir/build_stage1.zig")) {
  Copy-Item "$ZigSrcDir/ci/azure/build.zig" "$ZigSrcDir/build_stage1.zig";
}

$stage0_Zig    = Resolve-Path "$ZigDevKitPrefix/bin/zig.exe" # "Resolve-Path $env:EDEV_ZIG/zig.exe"

$stage1_BldDir    = New-Item "$ZigSrcDir/build/stage1" -ItemType Directory -Force
$stage1_BldFile   = Resolve-Path "$ZigSrcDir/build_stage1.zig"
$stage1_Zig       = "$stage1_BldDir/bin/zig.exe"
$stage1_BldArgs   = @(
  "build",
  "--search-prefix", "$ZigDevKitPrefix",
  "--prefix",        "$stage1_BldDir",
  "--build-file",    "$stage1_BldFile",
  "-Dstage1",
  "-Dstatic-llvm",
  "-Duse-zig-libcxx",
  "-Dtarget=$ZigTarget",
  "-Domit-stage2"
  <# "-Drelease", "-Dstrip", #>
)
"$stage0_Zig $($stage1_BldArgs -join " ")" | clip
& "$stage0_Zig" $stage1_BldArgs


$stage2_BldDir    = New-Item "$ZigSrcDir/build/stage2" -ItemType Directory -Force
$stage2_BldFile   = Resolve-Path "$ZigSrcDir/build.zig"
$stage2_Zig       = "$stage2_BldDir/bin/zig.exe"
$stage2_BldArgs = @(
  "build",
  "--search-prefix", "$ZigDevKitPrefix",
  "--prefix",        "$stage2_BldDir",
  "--build-file",    "$stage2_BldFile",
  "-Denable-llvm",
  "-Dstatic-llvm",
  "-Duse-zig-libcxx",
  "-Dtarget=$ZigTarget"
)
"$stage1_Zig $($stage2_BldArgs -join " ")" | clip
& "$stage1_Zig" $stage2_BldArgs

# # Test
# #& "$ZigInstallDir\bin\zig.exe" test "..\test\behavior.zig" -fno-stage1 -fLLVM -I "..\test" 2>&1 #stage2 is omitted
# & "$ZigInstallDir\bin\zig.exe" build test-toolchain -Dskip-non-native -Dskip-stage2-tests 2>&1
# & "$ZigInstallDir\bin\zig.exe" build test-std -Dskip-non-native  2>&1
