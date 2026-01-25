# =============================================================================
#  CONFIGURACIÓN DE INSTALACIÓN
#  [PERSONALIZAR]: Puedes cambiar el nombre de la carpeta 'TerminalHeartbeat'
#  por el nombre de tu proyecto o el apodo de tu pareja si prefieres.
# =============================================================================
$projectName = "TerminalHeartbeat" 
$folder = "$env:USERPROFILE\AppData\Local\$projectName"
$scriptName = "$projectName.ps1"
$scriptPath = Join-Path $folder $scriptName
$shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\$projectName.lnk"

# Limpieza de instalación previa (si existe)
if (Test-Path $folder) {
    Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $folder | Out-Null

# =============================================================================
#  GENERACIÓN DEL SCRIPT PRINCIPAL
#  Aquí se crea el archivo que se ejecutará en cada inicio.
# =============================================================================
$scriptContent = @'
# --- Configuración de la Ventana ---
$ui = $Host.UI.RawUI
# [PERSONALIZAR]: Título de la ventana
$ui.WindowTitle = "❤️ Hello World! ❤️" 

try {
    $ui.BufferSize = New-Object Management.Automation.Host.Size(50, 20)
    $ui.WindowSize = New-Object Management.Automation.Host.Size(50, 20)
} catch {}

# --- Frames del corazón (Animación ASCII) ---
$frames = @(
@"
     ████       ████
   ████████   ████████
  █████████████████████
  █████████████████████
   ███████████████████
    █████████████████
     ███████████████
       ████████████
         ████████
"@,
@"
      ████     ████
    ████████ ████████
   ███████████████████
   ███████████████████
    █████████████████
     ███████████████
       ████████████
         ████████
           ████
"@,
@"
     ████       ████
   ████████   ████████
  █████████████████████
  █████████████████████
   ███████████████████
    █████████████████
     ███████████████
       ████████████
         ████████
"@
)

# =============================================================================
#  LISTA DE MENSAJES
#  [PERSONALIZAR]: Reemplaza estos ejemplos con tus propias frases.
#  Pueden ser chistes internos, frases románticas o recordatorios.
# =============================================================================
$mensajes = @(
    "☕ Recuerda que nunca es suficiente café.",
    "🚀 Hoy será otro día increíble, como tú.",
    "💻 Hello World, Hello You.",
    "💪 Eres más fuerte de lo que crees.",
    "❤️ I love you to the moon and back.",
    "✨ A brillar, que el código no se escribe solo.",
    "🌵 Si la vida te da limones, haz un commit.",
    "💾 No olvides guardar tus cambios.",
    "🔥 Eres mi excepción favorita.",
    "🧘 Respira. Compila. Repite.",
    "🎯 Objetivo de hoy: Ser feliz (y arreglar ese bug).",
    "🌌 Que la fuerza te acompañe hoy."
)

# Seleccionar un mensaje al azar para esta sesión
$mensaje = Get-Random -InputObject $mensajes

# --- Inicio de la Animación ---
Clear-Host
Write-Host "Iniciando..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 1000

# Bucle infinito (hasta cerrar la ventana)
while ($true) {
    foreach ($frame in $frames) {
        if ([console]::KeyAvailable) { exit } 
        Clear-Host
        
        # Renderizar corazón en Rojo
        Write-Host $frame -ForegroundColor Red
        Write-Host ""
        
        # Renderizar mensaje en Blanco
        Write-Host $mensaje -ForegroundColor White
        
        Start-Sleep -Milliseconds 400
    }
}
'@ 

# Guardar el contenido en el archivo destino
$scriptContent | Set-Content -Path $scriptPath -Encoding UTF8 -Force

# =============================================================================
#  CONFIGURACIÓN DE AUTO-ARRANQUE (STARTUP)
#  Crea el acceso directo en la carpeta de inicio de Windows.
# =============================================================================
$WshShell = New-Object -ComObject WScript.Shell
$ShortcutObj = $WshShell.CreateShortcut($shortcutPath)
$ShortcutObj.TargetPath = "powershell.exe"
# Ejecuta el script en modo oculto/sin perfil para ser más rápido
$ShortcutObj.Arguments = "-ExecutionPolicy Bypass -WindowStyle Normal -File `"$scriptPath`""
$ShortcutObj.Save()

# =============================================================================
#  CONFIRMACIÓN
# =============================================================================
Write-Host "✅ Instalación completada con éxito." -ForegroundColor Green
Write-Host "📂 Archivos guardados en: $folder"
Write-Host "🚀 Se ejecutará automáticamente al reiniciar el PC."
Write-Host "ℹ️  Puedes probarlo ahora reiniciando o abriendo el archivo creado."
