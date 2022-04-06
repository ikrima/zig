[CmdletBinding(SupportsShouldProcess)]
param(
  # Attempt to build stage1
  [switch]$stage1,
  # Attempt to build stage1 using devkit
  [switch]$stage1Devkit,
  # Attempt to build stage2
  [switch]$stage2,
  # Build single threaded version
  [switch]$singleThreaded,
  # Build single threaded version
  [switch]$test
)
Import-Module PsUtil
$null = $PSCmdlet.ShouldProcess(( $PSBoundParameters.GetEnumerator() | Join-String -Separator " "))
$ZigSrcDir       = (ConvertTo-NormPath $PSScriptRoot).Replace("\", "/")
$ZigTarget       = "x86_64-windows-gnu"
$ZigDevKitName   = "zig+llvm+lld+clang-$ZigTarget-0.9.1"
$ZigDevKitPrefix = (ConvertTo-NormPath "$ZigSrcDir/../$ZigDevKitName").Replace("\", "/")
$ZigLlvmKitDir   = (ConvertTo-NormPath "$ZigSrcDir/../llvm+clang+lld-13.0.0-x86_64-windows-msvc-release-mt").Replace("\", "/")
$ZigDevKitURL    = "https://ziglang.org/deps/$ZigDevKitName.zip"

$devkit_exe      = (ConvertTo-NormPath "$env:EDEV_ZIGDIR/zig.exe").Replace("\", "/") # ConvertTo-NormPath "$ZigDevKitPrefix/bin/zig.exe"
$stage1_dir      = "build-stage1"                               # ConvertTo-NormPath "build-stage1"
$stage2_dir      = "build-stage2"                               # ConvertTo-NormPath "build-stage2"
$stage1_exe      = "$stage1_dir/bin/zig.exe"                    # ConvertTo-NormPath "stage1/bin/zig.exe"
$stage2_exe      = "$stage2_bld/bin/zig.exe"                    # ConvertTo-NormPath "stage2/bin/zig.exe"

if ($stage1) {
  $null = New-Item $stage1_dir -ItemType Container -Force -WhatIf:$WhatIfPreference
  Push-Location $stage1_dir
  $cmake_cmd = @{
    Command = "cmake.exe"
    CmdArgs = @(
      "..",
      "-Thost=x64",
      "-G", "Visual Studio 16 2019",
      "-A", "x64",
      "-DCMAKE_PREFIX_PATH=$ZigLlvmKitDir",
      "-DCMAKE_BUILD_TYPE=Release",
      # "-DZIG_OMIT_STAGE2=On",
      # "-DZIG_STATIC_LLVM=On"
      "-DZIG_SKIP_INSTALL_LIB_FILES=ON"
    )
    WhatIf  = $WhatIfPreference
  }
  Invoke-ShellCmd @cmake_cmd
  $msbuild_cmd = @{
    Command = "msbuild.exe"
    CmdArgs = @("-p:Configuration=Release", "INSTALL.vcxproj")
    WhatIf  = $WhatIfPreference
  }
  Invoke-ShellCmd @msbuild_cmd
  Pop-Location
}

if ($stage1Devkit) {
  # using zig master, not devkit
  $stage1_cmd = @{
    Command = $devkit_exe
    CmdArgs = @(
      "build",
      "--search-prefix", $ZigDevKitPrefix,
      "--prefix", $stage1_dir,
      "-Dstage1",
      # "-Domit-stage2",
      # "-Dstatic-llvm", # "-Dstatic-llvm=false",
      # "-Duse-zig-libcxx",
      "-Dtarget=$ZigTarget"
      # "--zig-lib-dir", $ZigLibDir,
      # "-Drelease",
      # "-Dstrip",
    ) + ($singleThreaded ? @(,"-Dsingle-threaded") : @())
    WhatIf  = $WhatIfPreference
  }
  Invoke-ShellCmd @stage1_cmd
}

if ($stage2) {
  # Write-Error "not working yet"
  $stage2_cmd = @{
    Command = $stage1_exe
    CmdArgs = @(
      "build",
      # "--search-prefix", $ZigDevKitPrefix,
      "--prefix", $stage2_dir
      # "-Denable-llvm",
      # "-Duse-zig-libcxx",
      # "-Dtarget=$ZigTarget"
      # "--zig-lib-dir",   $ZigLibDir,
    )
    WhatIf  = $WhatIfPreference
  }
  Invoke-ShellCmd @stage2_cmd
}

if ($test) {
  & $stage2_exe build test-std              -Dskip-release     -Dskip-non-native  2>&1
  & $stage2_exe test "test/behavior.zig"    -fno-stage1        -fLLVM -I "test"
  & $stage2_exe test "..\test\behavior.zig" -fno-stage1        -fLLVM -I "..\test" 2>&1 #stage2 is omitted
  & $stage2_exe build test-toolchain        -Dskip-non-native  -Dskip-stage2-tests 2>&1
  & $stage2_exe build test-std              -Dskip-non-native  2>&1
}