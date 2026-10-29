# Build a CSMDESK portable executable for Windows x64.
#
# Prerequisites (run once, as admin for the installers):
#   - Rust stable (rustup) with the x86_64-pc-windows-msvc toolchain
#   - Visual Studio Build Tools with "Desktop development with C++"
#   - Flutter SDK (stable) on PATH
#   - vcpkg with VCPKG_ROOT set, and:
#       vcpkg install libvpx:x64-windows-static libyuv:x64-windows-static `
#                     opus:x64-windows-static aom:x64-windows-static
#   - Python 3 (pip install brotli)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\build_portable.ps1
#   powershell -ExecutionPolicy Bypass -File tools\build_portable.ps1 -CustomTxt deploy\custom.txt
#
# Output: dist\CSMDESK-<version>.exe
param(
    [string]$CustomTxt = "",
    [switch]$SkipCargo
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot
try {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw "flutter not found on PATH"
    }
    if (-not $env:VCPKG_ROOT) {
        throw "VCPKG_ROOT is not set"
    }
    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
        throw "cargo not found on PATH"
    }
    python -c "import brotli" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "python package 'brotli' missing: pip install brotli" }

    $version = (Select-String -Path Cargo.toml -Pattern '^version\s*=\s*"([^"]+)"' |
        Select-Object -First 1).Matches.Groups[1].Value
    Write-Host "Building CSMDESK $version"

    $buildArgs = @("build.py", "--portable", "--flutter", "--skip-portable-pack", "--hwcodec")
    if ($SkipCargo) { $buildArgs += "--skip-cargo" }
    python @buildArgs
    if ($LASTEXITCODE -ne 0) { throw "build.py failed" }

    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }
    $bundle = "flutter\build\windows\$arch\runner\Release"
    if (-not (Test-Path "$bundle\rustdesk.exe")) {
        throw "Flutter bundle not found at $bundle\rustdesk.exe"
    }

    # Bake the signed custom client config into the portable payload.
    if ($CustomTxt) {
        if (-not (Test-Path $CustomTxt)) { throw "custom.txt not found: $CustomTxt" }
        Copy-Item $CustomTxt "$bundle\custom.txt" -Force
        Write-Host "Embedded $CustomTxt"
    }

    Copy-Item "target\release\deps\dylib_virtual_display.dll" "$bundle\" -Force -ErrorAction SilentlyContinue

    # Privacy-mode (virtual display) needs the Amyuni usbmmidd_v2 driver package,
    # same source as CI. Without it, privacy mode falls back to Mode 1 only.
    if (-not (Test-Path "$bundle\usbmmidd_v2")) {
        Invoke-WebRequest -Uri https://github.com/rustdesk-org/rdev/releases/download/usbmmidd_v2/usbmmidd_v2.zip -OutFile usbmmidd_v2.zip
        Expand-Archive usbmmidd_v2.zip -DestinationPath .
        Remove-Item -Path usbmmidd_v2\Win32 -Recurse -ErrorAction SilentlyContinue
        Remove-Item -Path "usbmmidd_v2\deviceinstaller64.exe", "usbmmidd_v2\deviceinstaller.exe", "usbmmidd_v2\usbmmidd.bat" -ErrorAction SilentlyContinue
        Move-Item -Force .\usbmmidd_v2 "$bundle\usbmmidd_v2"
    }

    # Privacy mode Mode 1 (topmost overlay) needs WindowInjection.dll. CI builds it
    # from the RustDeskTempTopMostWindow project; without it privacy mode uses the
    # magnifier fallback. Optional: place the DLL next to this script to bundle.
    if (Test-Path "libs\portable\WindowInjection.dll") {
        Copy-Item "libs\portable\WindowInjection.dll" "$bundle\" -Force
        Write-Host "WindowInjection.dll included (privacy mode Mode 1 enabled)"
    } else {
        Write-Warning "WindowInjection.dll not found - privacy mode 'Mode 1' (win_exclude_from_capture) will be used instead; build it from the RustDeskTempTopMostWindow project or download from a RustDesk CI run."
    }

    # Same rename as CI: the payload exe name decides the portable extraction
    # dir, the process image name, and whether the installer must rename the
    # copied exe to <APP_NAME>.exe (that rename is what failed with exit 9059).
    Move-Item -Force "$bundle\rustdesk.exe" "$bundle\CSMDESK.exe"

    Push-Location libs\portable
    python generate.py -f "../../$bundle" -o . -e "../../$bundle/CSMDESK.exe"
    if ($LASTEXITCODE -ne 0) { throw "portable packer failed" }
    Pop-Location

    New-Item -ItemType Directory -Force -Path dist | Out-Null
    $out = "dist\CSMDESK-$version.exe"
    Move-Item -Force "target\release\rustdesk-portable-packer.exe" $out
    Write-Host "Done: $((Resolve-Path $out).Path)"
}
finally {
    Pop-Location
}
