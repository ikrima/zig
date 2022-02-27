[CmdletBinding(SupportsShouldProcess = $true)]
param(
  # Attempt to build stage2
  [switch]$stage2,
  # Build single threaded version
  [switch]$singleThreaded
)
$ErrorActionPreference = "Stop"

$ZigSrcDir = Resolve-Path $PSScriptRoot
$ZigTarget = "x86_64-windows-gnu"
$ZigDevKitName = "zig+llvm+lld+clang-$ZigTarget-0.9.1"
$ZigDevKitPrefix = Resolve-Path "$ZigSrcDir/../$ZigDevKitName"
$ZigDevKitURL = "https://ziglang.org/deps/$ZigDevKitName.zip"

if (-not $stage2) {
  # using zig master, not devkit
  $master_zigExe = Resolve-Path "$env:EDEV_ZIGDIR/zig.exe"
  $stage0_BldArgs = @(
    "build",
    "--search-prefix", "$ZigDevKitPrefix",
    "-Dstage1",
    "-Dstatic-llvm",
    "-Duse-zig-libcxx",
    "-Dtarget=$ZigTarget",
    "-Domit-stage2"
  )
  if ($singleThreaded) { $stage0_BldArgs += "-Dsingle-threaded" }
  if ($PSCmdlet.ShouldProcess("$master_zigExe $($stage0_BldArgs -join " ")")) {
    & $master_zigExe $stage0_BldArgs
  }
}
else {
  Write-Error "not working yet"
  # master build.zig might be too new use devkits
  if (-not (Test-Path "$ZigSrcDir/build_stage1.zig")) {
    Copy-Item "$ZigSrcDir/ci/azure/build.zig" "$ZigSrcDir/build_stage1.zig";
  }

  $devkit_zigExe = Resolve-Path "$ZigDevKitPrefix/bin/zig.exe"

  $stage1_BldDir = New-Item "$ZigSrcDir/build/stage1" -ItemType Directory -Force
  $stage1_BldFile = Resolve-Path "$ZigSrcDir/build_stage1.zig"
  $stage1_zigExe = "$stage1_BldDir/bin/zig.exe"
  $stage1_BldArgs = @(
    "build",
    "--search-prefix", "$ZigDevKitPrefix",
    "--prefix", "$stage1_BldDir",
    "--build-file", "$stage1_BldFile",
    "-Dstage1",
    "-Dstatic-llvm",
    "-Duse-zig-libcxx",
    "-Dtarget=$ZigTarget",
    "-Domit-stage2"
    <# "-Drelease", "-Dstrip", #>
  )
  if ($PSCmdlet.ShouldProcess("$devkit_zigExe $($stage1_BldArgs -join " ")")) {
    & "$devkit_zigExe" $stage1_BldArgs
  }


  $stage2_BldDir = New-Item "$ZigSrcDir/build/stage2" -ItemType Directory -Force
  $stage2_BldFile = Resolve-Path "$ZigSrcDir/build.zig"
  $stage2_Zig = "$stage2_BldDir/bin/zig.exe"
  $stage2_BldArgs = @(
    "build",
    "--search-prefix", "$ZigDevKitPrefix",
    "--prefix", "$stage2_BldDir",
    "--build-file", "$stage2_BldFile",
    "-Denable-llvm",
    "-Dstatic-llvm",
    "-Duse-zig-libcxx",
    "-Dtarget=$ZigTarget"
  )
  if ($PSCmdlet.ShouldProcess("$stage1_zigExe $($stage2_BldArgs -join " ")")) {
    & "$stage1_zigExe" $stage2_BldArgs
  }

  # # Test
  # #& "$ZigInstallDir\bin\zig.exe" test "..\test\behavior.zig" -fno-stage1 -fLLVM -I "..\test" 2>&1 #stage2 is omitted
  # & "$ZigInstallDir\bin\zig.exe" build test-toolchain -Dskip-non-native -Dskip-stage2-tests 2>&1
  # & "$ZigInstallDir\bin\zig.exe" build test-std -Dskip-non-native  2>&1
}
