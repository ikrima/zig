[CmdletBinding(SupportsShouldProcess)]
param(
  # Attempt to build stage2
  [switch]$stage2,
  # Build single threaded version
  [switch]$singleThreaded
)
Import-Module PsUtil

$ZigSrcDir       = ConvertTo-NormPath $PSScriptRoot
$ZigTarget       = "x86_64-windows-gnu"
$ZigDevKitName   = "zig+llvm+lld+clang-$ZigTarget-0.9.1"
$ZigDevKitPrefix = ConvertTo-NormPath "$ZigSrcDir/../$ZigDevKitName"
$ZigDevKitURL    = "https://ziglang.org/deps/$ZigDevKitName.zip"

$devkit_exe      = ConvertTo-NormPath "$env:EDEV_ZIGDIR/zig.exe" # ConvertTo-NormPath "$ZigDevKitPrefix/bin/zig.exe"
$stage1_dir      = "build-stage1"                               # ConvertTo-NormPath "build-stage1"
$stage2_dir      = "build-stage2"                               # ConvertTo-NormPath "build-stage2"
$stage1_exe      = "$stage1_dir/bin/zig.exe"                    # ConvertTo-NormPath "stage1/bin/zig.exe"
$stage2_exe      = "$stage2_bld/bin/zig.exe"                    # ConvertTo-NormPath "stage2/bin/zig.exe"

if (-not $stage2) {
  # using zig master, not devkit
  $stage0_bld_args = @(
    "build",
    "--search-prefix", $ZigDevKitPrefix,
    "--prefix",        $stage1_dir,
    "-Dstage1",
    "-Domit-stage2",
    "-Dstatic-llvm", # "-Dstatic-llvm=false",
    "-Duse-zig-libcxx",
    "-Dtarget=$ZigTarget"
    # "--zig-lib-dir", $ZigLibDir,
    # "-Drelease",
    # "-Dstrip",
  )
  if ($singleThreaded) { $stage0_bld_args += "-Dsingle-threaded" }
  $stage1_bld_cmd = @(, $devkit_exe) + $stage0_bld_args -join " "
  Write-Host $stage1_bld_cmd
  if ($PSCmdlet.ShouldProcess($stage1_bld_cmd)) { & $devkit_exe $stage0_bld_args }
}

if ($stage2) {
  Write-Error "not working yet"

  $stage2_bld_args = @(
    "build",
    "--search-prefix", $ZigDevKitPrefix,
    "--prefix",        $stage2_dir,
    "-Denable-llvm",
    "-Duse-zig-libcxx",
    "-Dtarget=$ZigTarget"
    # "--zig-lib-dir",   $ZigLibDir,
  )
  $stage2_bld_cmd = @(, $stage1_exe) + $stage2_bld_args -join " "
  Write-Host $stage2_bld_cmd
  if ($PSCmdlet.ShouldProcess($stage2_bld_cmd)) { & $stage1_exe $stage2_bld_args }

  # Test
  # & $stage2_exe build test-std -Dskip-release -Dskip-non-native  2>&1
  # & $stage2_exe test "test/behavior.zig" -fno-stage1 -fLLVM -I "test"
  # & $stage2_exe test "..\test\behavior.zig" -fno-stage1 -fLLVM -I "..\test" 2>&1 #stage2 is omitted
  # & $stage2_exe build test-toolchain -Dskip-non-native -Dskip-stage2-tests 2>&1
  # & $stage2_exe build test-std -Dskip-non-native  2>&1
}
