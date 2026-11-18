# Exporta el módulo de RA de Unity y lo deja donde lo busca el APK.
#
# Uso (desde la carpeta TouristMAR):
#   powershell -ExecutionPolicy Bypass -File scripts\exportar-unity.ps1
#
# Por defecto usa el proyecto de Unity del repo (apps\ar-module\Marcadores):
# lo copia a C:\ar\marcadores (ruta corta: las rutas largas rompen Unity en
# Windows, y así la caché de Unity no se sube a OneDrive) y lo exporta.
# -Proyecto: otra carpeta de proyecto de Unity (con Assets, Packages, ProjectSettings).

param(
    [string]$Proyecto = "",
    [string]$Unity = ""
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$salida = "C:\ar\salida\ar-marcadores"   # ruta corta para Unity; luego se copia al repo
$log = "C:\ar\export-unity.log"

# 1. Unity: la versión instalada en Unity Hub (la más nueva si hay varias).
if (-not $Unity) {
    $editores = Get-ChildItem "C:\Program Files\Unity\Hub\Editor" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    foreach ($e in $editores) {
        $exe = Join-Path $e.FullName "Editor\Unity.exe"
        if ((Test-Path $exe) -and (Test-Path (Join-Path $e.FullName "Editor\Data\PlaybackEngines\AndroidPlayer"))) { $Unity = $exe; break }
    }
}
if (-not $Unity -or -not (Test-Path $Unity)) { throw "No encontré Unity con Android Build Support en C:\Program Files\Unity\Hub\Editor." }
Write-Host "Unity:    $Unity"

# 2. El proyecto de Unity (por defecto, una copia del del repo).
if (-not $Proyecto) {
    $origen = Join-Path $repo "apps\ar-module\Marcadores"
    $Proyecto = "C:\ar\marcadores"
    Write-Host "Copiando $origen -> $Proyecto"
    New-Item -ItemType Directory -Force -Path $Proyecto | Out-Null
    foreach ($c in "Assets", "Packages", "ProjectSettings") {
        robocopy (Join-Path $origen $c) (Join-Path $Proyecto $c) /E /NFL /NDL /NJH /NJS /NP | Out-Null
    }
}
foreach ($c in "Assets", "ProjectSettings") {
    if (-not (Test-Path (Join-Path $Proyecto $c))) { throw "En '$Proyecto' falta la carpeta $c. ¿Es la carpeta del proyecto de Unity?" }
}
if (-not (Test-Path (Join-Path $Proyecto "Packages\manifest.json"))) {
    Write-Warning "Falta Packages\manifest.json: Unity abrirá el proyecto sin los paquetes de AR (AR Foundation / ARCore) y la exportación probablemente falle. Pídele la carpeta Packages a Erick."
}
Write-Host "Proyecto: $Proyecto"

# 3. El script que exporta (se copia a Assets\Editor del proyecto).
$editor = Join-Path $Proyecto "Assets\Editor"
New-Item -ItemType Directory -Force -Path $editor | Out-Null
Copy-Item (Join-Path $PSScriptRoot "unity\ExportarLibreria.cs") $editor -Force
# "Atrás" de Android cierra la RA y vuelve a la app.
$tm = Join-Path $Proyecto "Assets\TouristMAR"
New-Item -ItemType Directory -Force -Path $tm | Out-Null
Copy-Item (Join-Path $PSScriptRoot "unity\CerrarConAtras.cs") $tm -Force

# 4. Exportar sin abrir la ventana. La primera vez tarda (Unity arma su caché).
New-Item -ItemType Directory -Force -Path "C:\ar\salida" | Out-Null
Write-Host "Exportando... (la primera vez puede tardar 20-40 min; el detalle va en $log)"
$p = Start-Process -FilePath $Unity -Wait -PassThru -ArgumentList @(
    "-batchmode", "-quit", "-buildTarget", "Android",
    "-projectPath", "`"$Proyecto`"",
    "-executeMethod", "ExportarLibreria.Exportar",
    "-salida", "`"$salida`"",
    "-logFile", "`"$log`""
)
if ($p.ExitCode -ne 0 -or -not (Test-Path (Join-Path $salida "unityLibrary\build.gradle"))) {
    Write-Host ""
    Write-Host "La exportación falló (código $($p.ExitCode)). Últimas líneas del log:" -ForegroundColor Red
    Get-Content $log -Tail 40
    exit 1
}

# 5. Decirle al proyecto de Android dónde está el export. No se copia al repo:
#    dentro de OneDrive\...\TouristMAR las rutas pasan de 260 caracteres y
#    Windows no las copia. android\unity.local.properties no se sube a git y
#    Flutter no lo reescribe (local.properties sí).
$props = Join-Path $repo "apps\mobile\android\unity.local.properties"
$linea = "touristmar.unityExport=" + ($salida -replace '\\', '/')
Set-Content -Path $props -Value $linea -Encoding ASCII
Write-Host ""
Write-Host "Listo: export en $salida (apps\mobile\android\unity.local.properties -> $linea)" -ForegroundColor Green
Write-Host "Ahora compila el APK:"
Write-Host "  cd apps\mobile"
Write-Host "  flutter build apk --release --target-platform android-arm64 --dart-define=API_URL=https://touristmar-production.up.railway.app/api"
