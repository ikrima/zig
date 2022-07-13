using module PsUtil
using module MachineConfig

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
$null = $PSCmdlet.ShouldProcess(( $PSBoundParameters.GetEnumerator() | Join-String -Separator ' '))
[DevCfg]$dev_cfg        = Get-DevCfg
$zig_src_dir            = $PSScriptRoot | ConvertTo-NormPath
$ZigTarget              = 'x86_64-windows-msvc'
# $ZigDevKitName        = "zig+llvm+lld+clang-$ZigTarget-0.10.0-dev.2931+bdf3fa12f"
# $ZigDevKitURL         = "https://ziglang.org/deps/$ZigDevKitName.zip"
# $ZigDevKitLlvmDir     = "$zig_src_dir/../$ZigDevKitName"                                       | ConvertTo-NormPath
$ZigDevKitLlvmDir       = "$zig_src_dir/../llvm+clang+lld-13.0.0-x86_64-windows-msvc-release-mt" | ConvertTo-NormPath
$ZigLocalLlvmDir        = "$zig_src_dir/../zigllvm/instl/rel"                    | ConvertTo-NormPath
$ZigLlvmDir             = $stage1Devkit ? $ZigDevKitLlvmDir : $ZigLocalLlvmDir | ConvertTo-NormPath;
$stage0_exe             = "$($dev_cfg.zig_dir)/zig.exe"                        | ConvertTo-NormPath # ConvertTo-NormPath "$ZigLlvmKitDir/bin/zig.exe"
$vcpkg_toolchain_file   = $dev_cfg.vcpkg_toolchain_file                        | ConvertTo-NormPath
$vcpkg_overlay_triplets = $dev_cfg.vcpkg_overlay_triplets                      | ConvertTo-NormPath
$stage1_dir             = 'build-stage1'                                       | ConvertTo-NormPath
$stage2_dir             = 'build-stage2'                                       | ConvertTo-NormPath
$stage1_exe             = "$stage1_dir/bin/zig.exe"                            | ConvertTo-NormPath
$stage2_exe             = "$stage2_bld/bin/zig.exe"                            | ConvertTo-NormPath
$cmake_bld_dir          = 'build-cmake'                                        | ConvertTo-NormPath


if ($stage1) {
  $null = New-Item $cmake_bld_dir -ItemType Container -Force -WhatIf:$WhatIfPreference
  Push-Location $cmake_bld_dir
  try {
    Invoke-ShellCmd -WhatIf:$WhatIfPreference -Command 'cmake.exe' -CmdArgs @(
      '-G', 'Ninja'
      "-DCMAKE_PREFIX_PATH=$ZigLlvmDir"
      "-DCMAKE_TOOLCHAIN_FILE=$vcpkg_toolchain_file"
      "-DVCPKG_OVERLAY_TRIPLETS=$vcpkg_overlay_triplets"
      '-DVCPKG_TARGET_TRIPLET=x64-windows-llvm'
      "-DCMAKE_C_COMPILER=$ZigLlvmDir/bin/clang-cl.exe"
      "-DCMAKE_CXX_COMPILER=$ZigLlvmDir/bin/clang-cl.exe"
      "-DCMAKE_AR=$ZigLlvmDir/bin/llvm-lib.exe"
      "-DCMAKE_LINKER=$ZigLlvmDir/bin/lld-link.exe"
      "-DCMAKE_ASM_MASM_COMPILER=ml64.exe"
      "-DCMAKE_RC_COMPILER=rc.exe"
      "-DCMAKE_MT=mt.exe"
      '-DCMAKE_BUILD_TYPE=Release'
      "-DCMAKE_INSTALL_PREFIX=$stage1_dir"
      '-DZIG_STATIC_LLVM=On'
      # "-DZIG_OMIT_STAGE2=On",
      "-DZIG_STATIC=ON"
      "-DZIG_TARGET_TRIPLE=$ZigTarget"
      "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
      # "-DZIG_SKIP_INSTALL_LIB_FILES=ON"
      "-S$zig_src_dir"
      "-B$cmake_bld_dir"
    )
    # Invoke-ShellCmd -WhatIf:$WhatIfPreference -Command 'cmake.exe' -CmdArgs @(
    #   '--build', $cmake_bld_dir
    #   '--target', 'install'
    #   '-j', '28'
    # )
    # Invoke-ShellCmd -WhatIf:$WhatIfPreference -Command 'cmake.exe' -CmdArgs @(
    #   '..'

    #   '-G', 'Ninja',
    #   '-DCMAKE_C_COMPILER="cl.exe"'
    #   '-DCMAKE_CXX_COMPILER="cl.exe"'
    #   '-DMSVC_TOOLSET_VERSION=142'

    #   "-DCMAKE_INSTALL_PREFIX=$stage1_dir"
    #   "-DCMAKE_PREFIX_PATH=$ZigLlvmDir"
    #   '-DCMAKE_BUILD_TYPE=Release'
    #   '-DZIG_STATIC_LLVM=On'
    #   # "-DZIG_OMIT_STAGE2=On",
    #   "-DZIG_STATIC=ON"
    #   "-DZIG_TARGET_TRIPLE=$ZigTarget"
    #   # "-DZIG_SKIP_INSTALL_LIB_FILES=ON"
    #   "-DCMAKE_TOOLCHAIN_FILE=$vcpkg_toolchain_file"
    #   "-DVCPKG_OVERLAY_TRIPLETS=$vcpkg_overlay_triplets",
    #   "-DVCPKG_TARGET_TRIPLET=x64-windows"
    # )
    # Invoke-ShellCmd -WhatIf:$WhatIfPreference -Command 'msbuild.exe' -CmdArgs @(
    #   '-p:Configuration=Release'
    #   'INSTALL.vcxproj'
    # )
  }
  finally {
    Pop-Location
  }
}

if ($stage1Devkit) {
  # using zig master, not devkit
  $stage1_cmd = @{
    Command = $stage0_exe
    CmdArgs = @(
      'build',
      '--search-prefix', $ZigLlvmDir,
      '--prefix', $stage1_dir,
      '-Dstage1',
      # "-Domit-stage2",
      '-Dstatic-llvm',
      # "-Denable-llvm",
      '-Duse-zig-libcxx',
      "-Dtarget=$ZigTarget"
      # "--zig-lib-dir", $ZigLibDir,
      # "-Drelease",
      # "-Dstrip",
    ) + ($singleThreaded ? @(, '-fsingle-threaded') : @())
    WhatIf  = $WhatIfPreference
  }
  Invoke-ShellCmd @stage1_cmd
}

if ($stage2) {
  # Write-Error "not working yet"
  $stage2_cmd = @{
    Command = $stage1_exe
    CmdArgs = @(
      'build',
      '--search-prefix', $ZigLlvmDir,
      '--prefix', $stage2_dir,
      '-Dstatic-llvm'
      # "-Denable-llvm",
      # '-Duse-zig-libcxx',
      "-Dtarget=$ZigTarget"
      # "--zig-lib-dir",   $ZigLibDir,
    )
    WhatIf  = $WhatIfPreference
  }
  Invoke-ShellCmd @stage2_cmd
}

if ($test) {
  & $stage2_exe build test-std -Dskip-release -Dskip-non-native -fno-stage1 2>&1
  & $stage2_exe @('test', 'test/behavior.zig', '-I', 'test', '-fno-LLVM' , '-fno-stage1', '-target', $ZigTarget, '2>&1')
  & $stage2_exe @('build', 'test-std'       , '-Dskip-release'    , '-Dskip-non-native'   , '2>&1' )
  & $stage2_exe @('build', 'test-toolchain' , '-Dskip-non-native' , '-Dskip-stage2-tests' , '2>&1' )
  & $stage2_exe @('build', 'test-std'       , '-Dskip-non-native' , '2>&1'                         )
  & $stage2_exe @('test', 'test/behavior.zig', '-I', 'test', '-fLLVM'    , '-fno-stage1' ) 2>&1
  & $stage2_exe @('test', 'test/behavior.zig', '-I', 'test', '-fno-LLVM' , '-fno-stage1' ) 2>&1
  # & $stage2_exe @("test", "test/behavior.zig", "-I", "test", "-fLLVM"    , "-target", $ZigTarget, "--test-cmd", "qemu-aarch64", "--test-cmd-bin" )
  # & $stage2_exe @("test", "test/behavior.zig", "-I", "test", "-fno-LLVM" , "-target", $ZigTarget, "--test-cmd", "qemu-aarch64", "--test-cmd-bin" )
  # & $stage2_exe @("test", "test/behavior.zig", "-I", "test", "-ofmt=c"                                                                                )
  # & $stage2_exe @("test", "test/behavior.zig", "-I", "test", "-fno-LLVM" , "-target", "wasm32-wasi"  , "--test-cmd"    , "wasmtime", "--test-cmd-bin" )
  # & $stage2_exe @("test", "test/behavior.zig", "-I", "test", "-fLLVM"    , "-target", "wasm32-wasi"  , "--test-cmd"    , "wasmtime", "--test-cmd-bin" )
  # & $stage2_exe @("test", "test/behavior.zig", "-I", "test", "-fno-LLVM" , "-target", "arm-linux"    , "--test-cmd"    , "qemu-arm", "--test-cmd-bin" )
  # & $stage2_exe @("test", "test/behavior.zig", "-I", "test", "-fLLVM"    , "-target", "aarch64-macos", "--test-no-exec"                               )
  # & $stage2_exe @("test", "test/behavior.zig", "-I", "test", "-fno-LLVM" , "-target", "aarch64-macos", "--test-no-exec"                               )
  # & $stage2_exe @("test", "test/behavior.zig", "-I", "test", "-fLLVM"    , "-target", "x86_64-macos" , "--test-no-exec"                               )
  # & $stage2_exe @("test", "test/behavior.zig", "-I", "test", "-fno-LLVM" , "-target", "x86_64-macos" , "--test-no-exec"                               )
}



# $cmake_cmd = @{
#   Command = 'cmake.exe'
#   CmdArgs = @(
#     '..'
#     '-Thost=x64'
#     '-G', 'Visual Studio 16 2019'
#     '-A', 'x64'
#     "-DCMAKE_INSTALL_PREFIX=$stage1_dir"
#     "-DCMAKE_PREFIX_PATH=$ZigLlvmDir"
#     '-DCMAKE_BUILD_TYPE=Debug'
#     "-DCMAKE_TOOLCHAIN_FILE=$vcpkg_toolchain_file"
#     # "-DZIG_OMIT_STAGE2=On",
#     '-DZIG_STATIC_LLVM=On'
#     # "-DZIG_STATIC=ON",
#     # "-DZIG_SKIP_INSTALL_LIB_FILES=ON"
#   )
#   WhatIf  = $WhatIfPreference
# }
# $msbuild_cmd = @{
#   Command = 'msbuild.exe'
#   CmdArgs = @(
#     '-p:Configuration=Debug'
#     'INSTALL.vcxproj'
#   )
#   WhatIf  = $WhatIfPreference
# }