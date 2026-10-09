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
$apiUrl = "https://web-three-pi-68.vercel.app"

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
# =============================================================================

$apiBase = "__API_BASE__"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Hide Console Window ---
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
[Win32]::ShowWindow([Win32]::GetConsoleWindow(), 0) | Out-Null

# =============================================================================
#  HEART ICON (GDI+ 32x32)
# =============================================================================
function New-HeartIcon {
    param([float]$scale = 1.0, [int]$size = 32, [System.Drawing.Color]$color)
    if (-not $color) { $color = [System.Drawing.Color]::FromArgb(220, 30, 50) }

    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $points = New-Object System.Collections.ArrayList
    $steps = 150
    $fitScale = ($size / 38.0) * $scale
    for ($i = 0; $i -lt $steps; $i++) {
        $t = ($i / $steps) * 2 * [Math]::PI
        $rawX = 16 * [Math]::Pow([Math]::Sin($t), 3)
        $rawY = 13 * [Math]::Cos($t) - 5 * [Math]::Cos(2 * $t) - 2 * [Math]::Cos(3 * $t) - [Math]::Cos(4 * $t)
        $px = ($rawX * $fitScale) + ($size / 2)
        $py = (-$rawY * $fitScale) + ($size / 2) + ($size * 0.03)
        [void]$points.Add([System.Drawing.PointF]::new([float]$px, [float]$py))
    }

    $brush = New-Object System.Drawing.SolidBrush($color)
    $g.FillClosedCurve($brush, $points.ToArray([System.Drawing.PointF]), [System.Drawing.Drawing2D.FillMode]::Winding, 0.05)
    $brush.Dispose()
    $g.Dispose()

    $hIcon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hIcon).Clone()
    [Win32]::DestroyIcon($hIcon) | Out-Null
    $bmp.Dispose()
    return $icon
}

$script:icons = @(
    (New-HeartIcon -scale 0.88),
    (New-HeartIcon -scale 1.0),
    (New-HeartIcon -scale 1.12)
)
$script:frameIndex = 0

# =============================================================================
#  DATA FETCHING & CACHE
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
                return @{
                    messages  = @($cached.messages)
                    greetings = @{
                        morning   = @($cached.greetings.morning)
                        afternoon = @($cached.greetings.afternoon)
                        night     = @($cached.greetings.night)
                    }
                }
            } catch {}
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

$script:heartData = Get-HeartData
$script:currentPopup = $null

# =============================================================================
#  POPUP
# =============================================================================
function Show-Popup {
    # Close existing popup
    if ($script:currentPopup -and -not $script:currentPopup.IsDisposed) {
        $script:currentPopup.Close()
        $script:currentPopup = $null
    }

    $period = Get-TimePeriod
    $greetingList = @($script:heartData.greetings.$period)
    if ($greetingList.Count -eq 0) { $greetingList = @("Hola, mi amor") }
    $greeting = Get-Random -InputObject $greetingList

    $messageList = @($script:heartData.messages)
    if ($messageList.Count -eq 0) { $messageList = @("Te quiero") }
    $message = Get-Random -InputObject $messageList

    $popupW = 400
    $popupH = 260

    # Position above tray
    $cursorPos = [System.Windows.Forms.Cursor]::Position
    $screen = [System.Windows.Forms.Screen]::FromPoint($cursorPos).WorkingArea
    $x = [Math]::Min($cursorPos.X - ($popupW / 2), $screen.Right - $popupW - 12)
    $x = [Math]::Max($x, $screen.Left + 12)
    $y = $screen.Bottom - $popupH - 16

    $popup = New-Object System.Windows.Forms.Form
    $popup.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $popup.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $popup.Location = New-Object System.Drawing.Point([int]$x, [int]$y)
    $popup.Size = New-Object System.Drawing.Size($popupW, $popupH)
    $popup.BackColor = [System.Drawing.Color]::FromArgb(16, 16, 16)
    $popup.ShowInTaskbar = $false
    $popup.TopMost = $true
    $popup.Opacity = 0.97

    # Rounded corners
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 20
    $path.AddArc(0, 0, $r, $r, 180, 90)
    $path.AddArc($popupW - $r - 1, 0, $r, $r, 270, 90)
    $path.AddArc($popupW - $r - 1, $popupH - $r - 1, $r, $r, 0, 90)
    $path.AddArc(0, $popupH - $r - 1, $r, $r, 90, 90)
    $path.CloseFigure()
    $popup.Region = New-Object System.Drawing.Region($path)

    # Paint: border glow + large heart watermark
    $popup.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $w = $s.ClientSize.Width
        $h = $s.ClientSize.Height

        # Draw large decorative heart (watermark, bottom-right)
        $heartPoints = New-Object System.Collections.ArrayList
        $heartSize = 80
        $steps = 120
        $cx = $w - 60
        $cy = $h - 50
        for ($i = 0; $i -lt $steps; $i++) {
            $t = ($i / $steps) * 2 * [Math]::PI
            $rx = 16 * [Math]::Pow([Math]::Sin($t), 3)
            $ry = 13 * [Math]::Cos($t) - 5 * [Math]::Cos(2 * $t) - 2 * [Math]::Cos(3 * $t) - [Math]::Cos(4 * $t)
            $sc = $heartSize / 38.0
            $px = ($rx * $sc) + $cx
            $py = (-$ry * $sc) + $cy
            [void]$heartPoints.Add([System.Drawing.PointF]::new([float]$px, [float]$py))
        }
        $heartBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(18, 220, 30, 50))
        $g.FillClosedCurve($heartBrush, $heartPoints.ToArray([System.Drawing.PointF]), [System.Drawing.Drawing2D.FillMode]::Winding, 0.05)
        $heartBrush.Dispose()

        # Border
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 220, 30, 50), 1.5)
        $bp = New-Object System.Drawing.Drawing2D.GraphicsPath
        $br = 20
        $bp.AddArc(1, 1, $br, $br, 180, 90)
        $bp.AddArc($w - $br - 2, 1, $br, $br, 270, 90)
        $bp.AddArc($w - $br - 2, $h - $br - 2, $br, $br, 0, 90)
        $bp.AddArc(1, $h - $br - 2, $br, $br, 90, 90)
        $bp.CloseFigure()
        $g.DrawPath($pen, $bp)
        $pen.Dispose()
        $bp.Dispose()

        # Top accent line
        $accentPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 220, 30, 50), 3)
        $g.DrawLine($accentPen, 30, 0, ($w - 30), 0)
        $accentPen.Dispose()
    })

    # Close button (X)
    $btnClose = New-Object System.Windows.Forms.Label
    $btnClose.Text = [char]0x2715
    $btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnClose.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    $btnClose.BackColor = [System.Drawing.Color]::Transparent
    $btnClose.Location = New-Object System.Drawing.Point(($popupW - 34), 8)
    $btnClose.Size = New-Object System.Drawing.Size(22, 22)
    $btnClose.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnClose.Add_Click({ $this.FindForm().Close() })
    $btnClose.Add_MouseEnter({ $btnClose.ForeColor = [System.Drawing.Color]::FromArgb(220, 30, 50) })
    $btnClose.Add_MouseLeave({ $btnClose.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100) })
    $popup.Controls.Add($btnClose)

    # Small heart icon beside greeting
    $lblHeartIcon = New-Object System.Windows.Forms.Label
    $lblHeartIcon.Text = [char]0x2665
    $lblHeartIcon.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 16)
    $lblHeartIcon.ForeColor = [System.Drawing.Color]::FromArgb(220, 30, 50)
    $lblHeartIcon.BackColor = [System.Drawing.Color]::Transparent
    $lblHeartIcon.Location = New-Object System.Drawing.Point(24, 18)
    $lblHeartIcon.Size = New-Object System.Drawing.Size(30, 30)
    $popup.Controls.Add($lblHeartIcon)

    # Greeting
    $lblGreeting = New-Object System.Windows.Forms.Label
    $lblGreeting.Text = $greeting
    $lblGreeting.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
    $lblGreeting.ForeColor = [System.Drawing.Color]::FromArgb(220, 30, 50)
    $lblGreeting.BackColor = [System.Drawing.Color]::Transparent
    $lblGreeting.Location = New-Object System.Drawing.Point(56, 18)
    $lblGreeting.Size = New-Object System.Drawing.Size(($popupW - 100), 32)
    $lblGreeting.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $popup.Controls.Add($lblGreeting)

    # Separator
    $sep = New-Object System.Windows.Forms.Panel
    $sep.BackColor = [System.Drawing.Color]::FromArgb(40, 220, 30, 50)
    $sep.Location = New-Object System.Drawing.Point(28, 58)
    $sep.Size = New-Object System.Drawing.Size(($popupW - 56), 1)
    $popup.Controls.Add($sep)

    # Message (supports emoji + multiline via \n in the text)
    $lblMessage = New-Object System.Windows.Forms.Label
    $lblMessage.Text = $message
    $lblMessage.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 11.5, [System.Drawing.FontStyle]::Regular)
    $lblMessage.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
    $lblMessage.BackColor = [System.Drawing.Color]::Transparent
    $lblMessage.Location = New-Object System.Drawing.Point(28, 72)
    $lblMessage.Size = New-Object System.Drawing.Size(($popupW - 56), 160)
    $lblMessage.TextAlign = [System.Drawing.ContentAlignment]::TopLeft
    $popup.Controls.Add($lblMessage)

    # Close when clicking outside
    $popup.Add_Deactivate({ $this.Close() })

    # Track this popup
    $script:currentPopup = $popup

    # Activate properly so Deactivate fires
    $popup.Show()
    $popup.Activate()
}

# =============================================================================
#  NOTIFY ICON
# =============================================================================
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = $script:icons[1]
$notifyIcon.Visible = $true
$notifyIcon.Text = "Terminal Heartbeat"

# Context menu — only Close
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$contextMenu.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$contextMenu.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$contextMenu.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::System

$menuClose = New-Object System.Windows.Forms.ToolStripMenuItem
$menuClose.Text = "Cerrar"
$menuClose.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$menuClose.Add_Click({
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
[void]$contextMenu.Items.Add($menuClose)
$notifyIcon.ContextMenuStrip = $contextMenu

# Left-click = open popup
$notifyIcon.Add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        Show-Popup
    }
})

# =============================================================================
#  TIMERS
# =============================================================================
# Animation (heartbeat pulse)
$animTimer = New-Object System.Windows.Forms.Timer
$animTimer.Interval = 500
$animTimer.Add_Tick({
    $script:frameIndex = ($script:frameIndex + 1) % $script:icons.Count
    $notifyIcon.Icon = $script:icons[$script:frameIndex]
})
$animTimer.Start()

# Refresh data every hour
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
