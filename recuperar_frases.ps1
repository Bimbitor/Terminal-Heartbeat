# =============================================================================
#  Terminal Heartbeat - Recuperar frases de una instalacion anterior
# =============================================================================
#  Lee las frases guardadas en el equipo y las escribe en un archivo de texto.
#  NO modifica ni borra nada: solo lee.
#
#  Uso:
#    powershell -ExecutionPolicy Bypass -File .\recuperar_frases.ps1
# =============================================================================
param(
    [string]$Destino = (Join-Path ([Environment]::GetFolderPath("Desktop")) "frases_recuperadas.txt"),
    [string]$Carpeta = (Join-Path $env:LOCALAPPDATA "TerminalHeartbeat")
)

$ErrorActionPreference = "Stop"
$folder = $Carpeta

Write-Host ""
Write-Host "  Terminal Heartbeat - Recuperar frases" -ForegroundColor Red
Write-Host "  =====================================" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path $folder)) {
    Write-Host "  No hay ninguna instalacion en:" -ForegroundColor Yellow
    Write-Host "    $folder" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "  Enter para salir"
    exit 1
}

$frases = New-Object System.Collections.Generic.List[string]

# --- Fuente 1: el arreglo de mensajes dentro del script (v1.0) ---
# Se lee con el analizador de PowerShell en vez de ejecutar el script, para no
# correr codigo viejo solo por extraer texto.
$script = Join-Path $folder "TerminalHeartbeat.ps1"
if (Test-Path $script) {
    Write-Host "  Leyendo script instalado..." -ForegroundColor DarkGray
    try {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$null)
        $asignaciones = $ast.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $n.Left.Extent.Text -match '\$(mensajes|messages|frases)$'
        }, $true)

        foreach ($a in $asignaciones) {
            $textos = $a.Right.FindAll({
                param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst]
            }, $true)
            foreach ($t in $textos) {
                if ($t.Value.Trim()) { $frases.Add($t.Value) }
            }
        }
        Write-Host "    $($frases.Count) frases encontradas en el script." -ForegroundColor Green
    } catch {
        Write-Host "    No se pudo analizar el script: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- Fuente 2: la cache de la v2.0, por si el equipo ya tenia esa version ---
$cache = Join-Path $folder "cache.json"
$desdeCache = 0
if (Test-Path $cache) {
    Write-Host "  Leyendo cache..." -ForegroundColor DarkGray
    try {
        $datos = Get-Content $cache -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($m in @($datos.messages)) {
            if ($m -and $m.ToString().Trim()) { $frases.Add($m.ToString()); $desdeCache++ }
        }
        foreach ($periodo in "morning", "afternoon", "night") {
            foreach ($g in @($datos.greetings.$periodo)) {
                if ($g -and $g.ToString().Trim()) { $frases.Add($g.ToString()); $desdeCache++ }
            }
        }
        Write-Host "    $desdeCache entradas encontradas en la cache." -ForegroundColor Green
    } catch {
        Write-Host "    Cache ilegible (se ignora)." -ForegroundColor Yellow
    }
}

if ($frases.Count -eq 0) {
    Write-Host ""
    Write-Host "  No se encontro ninguna frase." -ForegroundColor Yellow
    Write-Host "  Copia manualmente esta carpeta por si acaso:" -ForegroundColor DarkGray
    Write-Host "    $folder" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "  Enter para salir"
    exit 1
}

# Quitar duplicados conservando el orden original
$unicas = New-Object System.Collections.Generic.List[string]
$vistas = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in $frases) { if ($vistas.Add($f)) { $unicas.Add($f) } }

# Escribir en UTF-8 con BOM para que acentos y emojis sobrevivan el viaje
$salida = New-Object System.Collections.Generic.List[string]
$salida.Add("Frases recuperadas de Terminal Heartbeat")
$salida.Add("Equipo: $env:COMPUTERNAME    Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
$salida.Add("Origen: $folder")
$salida.Add("Total: $($unicas.Count)")
$salida.Add("")
$salida.Add("--- una frase por bloque, separadas por una linea con ---")
$salida.Add("")
foreach ($f in $unicas) { $salida.Add($f); $salida.Add("---") }

[System.IO.File]::WriteAllLines($Destino, $salida, (New-Object System.Text.UTF8Encoding($true)))

Write-Host ""
Write-Host "  Listo: $($unicas.Count) frases recuperadas." -ForegroundColor Green
Write-Host "  Guardadas en:" -ForegroundColor White
Write-Host "    $Destino" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Vista previa:" -ForegroundColor DarkGray
foreach ($f in ($unicas | Select-Object -First 5)) {
    $p = ($f -replace "`r`n", " / " -replace "`n", " / ")
    if ($p.Length -gt 60) { $p = $p.Substring(0, 60) + "..." }
    Write-Host "    - $p" -ForegroundColor DarkGray
}
if ($unicas.Count -gt 5) { Write-Host "    ... y $($unicas.Count - 5) mas" -ForegroundColor DarkGray }
Write-Host ""
Write-Host "  Copia ese archivo antes de instalar la version nueva." -ForegroundColor Yellow
Write-Host ""
Read-Host "  Enter para salir"
