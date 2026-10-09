# =============================================================================
#  Terminal Heartbeat v2.0 — Installer
#  Usage:
#    Install:    powershell -ExecutionPolicy Bypass -File install_heart.ps1
#    Uninstall:  powershell -ExecutionPolicy Bypass -File install_heart.ps1 -Uninstall
# =============================================================================
param(
    [switch]$Uninstall
)

$projectName = "TerminalHeartbeat"
$folder = "$env:USERPROFILE\AppData\Local\$projectName"
$scriptName = "$projectName.ps1"
$scriptPath = Join-Path $folder $scriptName
$shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\$projectName.lnk"

# --- API URL (change this to your Vercel deployment) ---
$apiUrl = "https://terminal-heartbeat.vercel.app"

# =============================================================================
#  CLEANUP — Kill running process + remove all files
# =============================================================================
function Remove-HeartbeatInstallation {
    # Kill any running instance
    Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {
        try {
            $_.MainModule.FileName -and
            (Get-Content (Join-Path $folder $scriptName) -ErrorAction SilentlyContinue) -ne $null -and
            $_.Id -ne $PID
        } catch { $false }
    } | ForEach-Object {
        try { $_ | Stop-Process -Force -ErrorAction SilentlyContinue } catch {}
    }

    # Also try matching by command line
    Get-WmiObject Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match [regex]::Escape($scriptPath) -and $_.ProcessId -ne $PID } |
        ForEach-Object {
            try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
        }

    Start-Sleep -Milliseconds 500

    # Remove shortcut
    if (Test-Path $shortcutPath) {
        Remove-Item -Path $shortcutPath -Force -ErrorAction SilentlyContinue
    }

    # Remove data folder
    if (Test-Path $folder) {
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# =============================================================================
#  UNINSTALL MODE
# =============================================================================
if ($Uninstall) {
    Write-Host ""
    Write-Host "  Desinstalando Terminal Heartbeat..." -ForegroundColor Yellow
    Remove-HeartbeatInstallation
    Write-Host "  Desinstalacion completada. No quedan rastros." -ForegroundColor Green
    Write-Host ""
    exit 0
}

# =============================================================================
#  INSTALL MODE — Clean previous version first
# =============================================================================
Write-Host ""
Write-Host "  Terminal Heartbeat v2.0 — Instalador" -ForegroundColor Red
Write-Host "  =====================================" -ForegroundColor DarkGray
Write-Host ""

# Remove any previous installation (v1.0, v2.x, etc.)
if ((Test-Path $folder) -or (Test-Path $shortcutPath)) {
    Write-Host "  Limpiando version anterior..." -ForegroundColor Yellow
    Remove-HeartbeatInstallation
}

# Create fresh folder
New-Item -ItemType Directory -Path $folder | Out-Null

# =============================================================================
#  GENERATE MAIN SCRIPT
# =============================================================================
$scriptContent = @'
# =============================================================================
#  Terminal Heartbeat v2.0 — System Tray Client
#  Un corazon que late en silencio, esperando tu click.
# =============================================================================

# --- Configuration ---
$apiBase = "__API_BASE__"

# --- Load Assemblies ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Hide Console Window (P/Invoke) ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr hIcon);
}
"@
$consoleHwnd = [Win32]::GetConsoleWindow()
[Win32]::ShowWindow($consoleHwnd, 0) | Out-Null

# =============================================================================
#  HEART ICON GENERATOR (GDI+ Parametric Curve, 32x32)
# =============================================================================
function New-HeartIcon {
    param([float]$scale = 1.0)

    $size = 32
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $points = New-Object System.Collections.ArrayList
    $steps = 120
    for ($i = 0; $i -lt $steps; $i++) {
        $t = ($i / $steps) * 2 * [Math]::PI
        $rawX = 16 * [Math]::Pow([Math]::Sin($t), 3)
        $rawY = 13 * [Math]::Cos($t) - 5 * [Math]::Cos(2 * $t) - 2 * [Math]::Cos(3 * $t) - [Math]::Cos(4 * $t)

        $px = ($rawX * $scale * 0.42) + ($size / 2)
        $py = (-$rawY * $scale * 0.42) + ($size / 2) + 1

        [void]$points.Add([System.Drawing.PointF]::new([float]$px, [float]$py))
    }

    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 30, 50))
    $pointArray = $points.ToArray([System.Drawing.PointF])
    $g.FillClosedCurve($brush, $pointArray, [System.Drawing.Drawing2D.FillMode]::Winding, 0.1)

    $brush.Dispose()
    $g.Dispose()

    $hIcon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hIcon).Clone()
    [Win32]::DestroyIcon($hIcon) | Out-Null
    $bmp.Dispose()

    return $icon
}

# Generate 3 frames for the pulse animation
$script:icons = @(
    (New-HeartIcon -scale 0.82),
    (New-HeartIcon -scale 1.0),
    (New-HeartIcon -scale 1.10)
)
$script:frameIndex = 0

# =============================================================================
#  DATA FETCHING & OFFLINE CACHE
# =============================================================================
$script:dataFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:cacheFile = Join-Path $script:dataFolder "cache.json"

$script:defaultData = @{
    messages = @(
        "Te quiero mucho.",
        "Hoy sera un gran dia, como tu.",
        "Eres mi persona favorita.",
        "Recuerda que siempre estoy pensando en ti."
    )
    greetings = @{
        morning   = @("Buenos dias, mi amor")
        afternoon = @("Buenas tardes, preciosa")
        night     = @("Buenas noches, mi vida")
    }
}

function Get-HeartData {
    try {
        $msgResp = Invoke-RestMethod -Uri "$apiBase/api/messages" -TimeoutSec 5 -ErrorAction Stop
        $grtResp = Invoke-RestMethod -Uri "$apiBase/api/greetings" -TimeoutSec 5 -ErrorAction Stop

        $data = @{
            messages  = @($msgResp.messages | ForEach-Object { $_.text })
            greetings = @{
                morning   = @($grtResp.greetings.morning | ForEach-Object { $_.text })
                afternoon = @($grtResp.greetings.afternoon | ForEach-Object { $_.text })
                night     = @($grtResp.greetings.night | ForEach-Object { $_.text })
            }
            lastFetch = (Get-Date).ToString("o")
        }
        $data | ConvertTo-Json -Depth 5 | Set-Content -Path $script:cacheFile -Encoding UTF8 -Force
        return $data
    }
    catch {
        if (Test-Path $script:cacheFile) {
            try {
                $cached = Get-Content $script:cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json
                $result = @{
                    messages  = @($cached.messages)
                    greetings = @{
                        morning   = @($cached.greetings.morning)
                        afternoon = @($cached.greetings.afternoon)
                        night     = @($cached.greetings.night)
                    }
                }
                return $result
            }
            catch {}
        }
        return $script:defaultData
    }
}

function Get-TimePeriod {
    $hour = (Get-Date).Hour
    if ($hour -ge 6 -and $hour -lt 12) { return "morning" }
    elseif ($hour -ge 12 -and $hour -lt 20) { return "afternoon" }
    else { return "night" }
}

# Initial data fetch
$script:heartData = Get-HeartData

# =============================================================================
#  POPUP WINDOW
# =============================================================================
function Show-Popup {
    $period = Get-TimePeriod
    $greetingList = @($script:heartData.greetings.$period)
    if ($greetingList.Count -eq 0) { $greetingList = @("Hola, mi amor") }
    $greeting = Get-Random -InputObject $greetingList

    $messageList = @($script:heartData.messages)
    if ($messageList.Count -eq 0) { $messageList = @("Te quiero") }
    $message = Get-Random -InputObject $messageList

    $popupW = 360
    $popupH = 180

    $cursorPos = [System.Windows.Forms.Cursor]::Position
    $screen = [System.Windows.Forms.Screen]::FromPoint($cursorPos).WorkingArea
    $x = [Math]::Min($cursorPos.X - ($popupW / 2), $screen.Right - $popupW - 8)
    $x = [Math]::Max($x, $screen.Left + 8)
    $y = $screen.Bottom - $popupH - 12

    $popup = New-Object System.Windows.Forms.Form
    $popup.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $popup.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $popup.Location = New-Object System.Drawing.Point([int]$x, [int]$y)
    $popup.Size = New-Object System.Drawing.Size($popupW, $popupH)
    $popup.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 18)
    $popup.ShowInTaskbar = $false
    $popup.TopMost = $true
    $popup.Opacity = 0.96

    # Rounded corners
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 16
    $path.AddArc(0, 0, $r, $r, 180, 90)
    $path.AddArc($popupW - $r - 1, 0, $r, $r, 270, 90)
    $path.AddArc($popupW - $r - 1, $popupH - $r - 1, $r, $r, 0, 90)
    $path.AddArc(0, $popupH - $r - 1, $r, $r, 90, 90)
    $path.CloseFigure()
    $popup.Region = New-Object System.Drawing.Region($path)

    # Custom paint for border glow
    $popup.Add_Paint({
        param($s, $e)
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(100, 220, 30, 50), 1.5)
        $borderPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $br = 16
        $bw = $s.ClientSize.Width
        $bh = $s.ClientSize.Height
        $borderPath.AddArc(1, 1, $br, $br, 180, 90)
        $borderPath.AddArc($bw - $br - 2, 1, $br, $br, 270, 90)
        $borderPath.AddArc($bw - $br - 2, $bh - $br - 2, $br, $br, 0, 90)
        $borderPath.AddArc(1, $bh - $br - 2, $br, $br, 90, 90)
        $borderPath.CloseFigure()
        $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $e.Graphics.DrawPath($pen, $borderPath)
        $pen.Dispose()
        $borderPath.Dispose()
    })

    # Greeting label
    $lblGreeting = New-Object System.Windows.Forms.Label
    $lblGreeting.Text = $greeting
    $lblGreeting.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lblGreeting.ForeColor = [System.Drawing.Color]::FromArgb(220, 30, 50)
    $lblGreeting.BackColor = [System.Drawing.Color]::Transparent
    $lblGreeting.Location = New-Object System.Drawing.Point(24, 20)
    $lblGreeting.Size = New-Object System.Drawing.Size(($popupW - 48), 30)
    $lblGreeting.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $popup.Controls.Add($lblGreeting)

    # Separator
    $separator = New-Object System.Windows.Forms.Panel
    $separator.BackColor = [System.Drawing.Color]::FromArgb(60, 220, 30, 50)
    $separator.Location = New-Object System.Drawing.Point(24, 58)
    $separator.Size = New-Object System.Drawing.Size(($popupW - 48), 1)
    $popup.Controls.Add($separator)

    # Message label
    $lblMessage = New-Object System.Windows.Forms.Label
    $lblMessage.Text = $message
    $lblMessage.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
    $lblMessage.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    $lblMessage.BackColor = [System.Drawing.Color]::Transparent
    $lblMessage.Location = New-Object System.Drawing.Point(24, 72)
    $lblMessage.Size = New-Object System.Drawing.Size(($popupW - 48), 80)
    $lblMessage.TextAlign = [System.Drawing.ContentAlignment]::TopLeft
    $popup.Controls.Add($lblMessage)

    # Small heart decoration bottom-right
    $lblHeart = New-Object System.Windows.Forms.Label
    $lblHeart.Text = [char]0x2665
    $lblHeart.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblHeart.ForeColor = [System.Drawing.Color]::FromArgb(80, 220, 30, 50)
    $lblHeart.BackColor = [System.Drawing.Color]::Transparent
    $lblHeart.Location = New-Object System.Drawing.Point(($popupW - 36), ($popupH - 28))
    $lblHeart.Size = New-Object System.Drawing.Size(20, 20)
    $popup.Controls.Add($lblHeart)

    # Close on deactivate
    $popup.Add_Deactivate({ $popup.Close() })

    $popup.Show()
}

# =============================================================================
#  NOTIFY ICON + CONTEXT MENU
# =============================================================================
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = $script:icons[1]
$notifyIcon.Visible = $true
$notifyIcon.Text = "Terminal Heartbeat"

# Context menu
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$contextMenu.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$contextMenu.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
$contextMenu.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::System

$menuNew = New-Object System.Windows.Forms.ToolStripMenuItem
$menuNew.Text = "Nuevo mensaje"
$menuNew.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
$menuNew.Add_Click({ Show-Popup })

$menuRefresh = New-Object System.Windows.Forms.ToolStripMenuItem
$menuRefresh.Text = "Actualizar datos"
$menuRefresh.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
$menuRefresh.Add_Click({ $script:heartData = Get-HeartData })

$menuSep = New-Object System.Windows.Forms.ToolStripSeparator

$menuClose = New-Object System.Windows.Forms.ToolStripMenuItem
$menuClose.Text = "Cerrar"
$menuClose.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$menuClose.Add_Click({
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

[void]$contextMenu.Items.Add($menuNew)
[void]$contextMenu.Items.Add($menuRefresh)
[void]$contextMenu.Items.Add($menuSep)
[void]$contextMenu.Items.Add($menuClose)
$notifyIcon.ContextMenuStrip = $contextMenu

# Left-click opens popup
$notifyIcon.Add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        Show-Popup
    }
})

# =============================================================================
#  ANIMATION TIMER (heartbeat pulse)
# =============================================================================
$animTimer = New-Object System.Windows.Forms.Timer
$animTimer.Interval = 500
$animTimer.Add_Tick({
    $script:frameIndex = ($script:frameIndex + 1) % $script:icons.Count
    $notifyIcon.Icon = $script:icons[$script:frameIndex]
})
$animTimer.Start()

# =============================================================================
#  REFRESH TIMER (fetch new data every hour)
# =============================================================================
$refreshTimer = New-Object System.Windows.Forms.Timer
$refreshTimer.Interval = 3600000
$refreshTimer.Add_Tick({ $script:heartData = Get-HeartData })
$refreshTimer.Start()

# =============================================================================
#  RUN
# =============================================================================
[System.Windows.Forms.Application]::Run()
'@

# Inject the API URL
$scriptContent = $scriptContent.Replace("__API_BASE__", $apiUrl)

# Save the generated script
$scriptContent | Set-Content -Path $scriptPath -Encoding UTF8 -Force

# =============================================================================
#  CREATE STARTUP SHORTCUT
# =============================================================================
$WshShell = New-Object -ComObject WScript.Shell
$ShortcutObj = $WshShell.CreateShortcut($shortcutPath)
$ShortcutObj.TargetPath = "powershell.exe"
$ShortcutObj.Arguments = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$scriptPath`""
$ShortcutObj.WindowStyle = 7  # Minimized
$ShortcutObj.Save()

# =============================================================================
#  CONFIRMATION
# =============================================================================
Write-Host ""
Write-Host "  Instalacion completada." -ForegroundColor Green
Write-Host ""
Write-Host "  Archivos:   $folder" -ForegroundColor DarkGray
Write-Host "  Startup:    $shortcutPath" -ForegroundColor DarkGray
Write-Host "  API:        $apiUrl" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  El corazon aparecera en tu bandeja del sistema" -ForegroundColor White
Write-Host "  cada vez que enciendas el PC." -ForegroundColor White
Write-Host ""
Write-Host "  Para desinstalar:" -ForegroundColor DarkGray
Write-Host "  powershell -ExecutionPolicy Bypass -File install_heart.ps1 -Uninstall" -ForegroundColor DarkGray
Write-Host ""

# Ask if the user wants to launch it now
$response = Read-Host "  Quieres probarlo ahora? (s/n)"
if ($response -eq "s" -or $response -eq "S" -or $response -eq "si") {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$scriptPath`""
    Write-Host ""
    Write-Host "  Lanzado! Busca el corazon en la bandeja del sistema." -ForegroundColor Red
    Write-Host ""
}
