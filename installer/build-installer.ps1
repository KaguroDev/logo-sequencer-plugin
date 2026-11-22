# Compila el plugin y genera el instalador .exe (NSIS) en release\.
# Uso (desde la raíz del proyecto):  powershell -ExecutionPolicy Bypass -File installer\build-installer.ps1
# Equivale a:  cmake --build --preset windows-x64-vs2026 --target installer

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$preset = 'windows-x64-vs2026'

# (Re)configura si no hay caché o si aún no existe el destino "installer"
# (p. ej. NSIS se instaló después de la primera configuración).
if (-not (Test-Path 'build_x64\installer.vcxproj')) {
    cmake --preset $preset
    if ($LASTEXITCODE) { throw 'Falló la configuración de CMake' }
}
if (-not (Test-Path 'build_x64\installer.vcxproj')) {
    throw 'No se encontró NSIS 3 (https://nsis.sourceforge.io o winget install NSIS.NSIS)'
}

cmake --build --preset $preset --target installer
if ($LASTEXITCODE) { throw 'Falló la generación del instalador' }

Get-ChildItem 'release\*-setup.exe' | Select-Object FullName, Length
