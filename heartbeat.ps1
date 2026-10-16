# =============================================================================
#  Terminal Heartbeat v2.0 - System Tray Client
# =============================================================================
# -Startup is passed by the Startup-folder shortcut. At logon the notification
# area rejects tray icons for the first few seconds and an icon registered that
# early is silently dropped, so that launch path waits before starting.
param([switch]$Startup)

$apiBase = "https://web-three-pi-68.vercel.app"
$projectName = "TerminalHeartbeat"
$startupDelaySeconds = 25

$script:dataFolder = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:logFile = Join-Path $script:dataFolder "startup.log"

function Write-Log {
    param([string]$Message)
    try {
        $line = "{0}  {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $Message
        Add-Content -Path $script:logFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

# Keep only the last 200 lines so the log never grows without bound
try {
    if (Test-Path $script:logFile) {
        $existing = @(Get-Content $script:logFile -ErrorAction SilentlyContinue)
        if ($existing.Count -gt 200) {
            $existing[-200..-1] | Set-Content -Path $script:logFile -Encoding UTF8
        }
    }
} catch {}

Write-Log "=== Launch (PID $PID) ==="

# --- Single Instance Check ---
$mutex = New-Object System.Threading.Mutex($false, "TerminalHeartbeatMutex")
if (-not $mutex.WaitOne(0, $false)) {
    Write-Log "Another instance already running - exiting"
    exit
}

if ($Startup) {
    Write-Log "Startup launch - waiting ${startupDelaySeconds}s for the notification area"
    Start-Sleep -Seconds $startupDelaySeconds
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Route UI-thread exceptions to our own handler instead of the .NET crash dialog.
# This must run before any Control exists, so it stays here at the top. Without
# it, a single drawing hiccup shows an error box and takes the heart down.
try {
    [System.Windows.Forms.Application]::SetUnhandledExceptionMode(
        [System.Windows.Forms.UnhandledExceptionMode]::CatchException)
    [System.Windows.Forms.Application]::add_ThreadException({
        param($s, $e)
        try { Write-Log "UI exception (ignored): $($e.Exception.Message)" } catch {}
    })
} catch {}

# --- Hide Console Window + HTTP client with a real timeout ---
Add-Type @"
using System;
using System.Net;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr hIcon);
}
public class TimeoutWebClient : WebClient {
    public int TimeoutMs = 8000;
    protected override WebRequest GetWebRequest(Uri address) {
        WebRequest r = base.GetWebRequest(address);
        r.Timeout = TimeoutMs;
        return r;
    }
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

function Invoke-Utf8Rest {
    param([string]$Uri)
    $wc = New-Object TimeoutWebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    try {
        $json = $wc.DownloadString($Uri)
        return ($json | ConvertFrom-Json)
    } finally { $wc.Dispose() }
}

# Local-only: never touches the network, so it is safe to call during startup.
function Get-CachedData {
    if (Test-Path $script:cacheFile) {
        try {
            $cached = Get-Content $script:cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $data = @{
                messages  = @($cached.messages)
                greetings = @{
                    morning   = @($cached.greetings.morning)
                    afternoon = @($cached.greetings.afternoon)
                    night     = @($cached.greetings.night)
                }
            }
            if ($data.messages.Count -gt 0) {
                Write-Log "Loaded cache ($($data.messages.Count) messages)"
                return $data
            }
        } catch { Write-Log "Cache unreadable: $($_.Exception.Message)" }
    }
    Write-Log "Using built-in defaults"
    return $script:defaultData
}

function Update-HeartData {
    try {
        $msgResp = Invoke-Utf8Rest -Uri "$apiBase/api/messages"
        $grtResp = Invoke-Utf8Rest -Uri "$apiBase/api/greetings"
        $data = @{
            messages  = @($msgResp.messages | ForEach-Object { $_.text })
            greetings = @{
                morning   = @($grtResp.greetings.morning | ForEach-Object { $_.text })
                afternoon = @($grtResp.greetings.afternoon | ForEach-Object { $_.text })
                night     = @($grtResp.greetings.night | ForEach-Object { $_.text })
            }
            lastFetch = (Get-Date).ToString("o")
        }
        if ($data.messages.Count -eq 0) {
            Write-Log "API returned no messages - keeping current data"
            return
        }
        $data | ConvertTo-Json -Depth 5 | Set-Content -Path $script:cacheFile -Encoding UTF8 -Force
        $script:heartData = $data
        Write-Log "Fetched $($data.messages.Count) messages from API"
    }
    catch {
        Write-Log "Fetch failed: $($_.Exception.Message)"
    }
}

function Get-TimePeriod {
    $hour = (Get-Date).Hour
    if ($hour -ge 6 -and $hour -lt 12) { return "morning" }
    elseif ($hour -ge 12 -and $hour -lt 20) { return "afternoon" }
    else { return "night" }
}

$script:heartData = Get-CachedData
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

    # Paint: border glow + large heart watermark.
    # Everything here is decorative. A reentrant event can hand the handler
    # unbound arguments, so the sender and Graphics are resolved defensively and
    # the whole body is guarded: the popup must still show its text if the
    # decoration cannot be drawn, and must never take the application down.
    $popup.Add_Paint({
        param($s, $e)
        $form = if ($s) { $s } elseif ($this) { $this } else { $null }
        $g = if ($e) { $e.Graphics } else { $null }
        if ($null -eq $g -or $null -eq $form) { return }
        try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $w = $form.ClientSize.Width
        $h = $form.ClientSize.Height

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
        } catch {
            Write-Log "Popup decoration skipped: $($_.Exception.Message)"
        }
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
    $lblGreeting.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 15, [System.Drawing.FontStyle]::Bold)
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
#  UNINSTALL
# =============================================================================
# The script lives inside the folder it has to delete, so the actual cleanup is
# handed to a detached helper that waits for this process to exit first.
function Invoke-Uninstall {
    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Esto eliminara Terminal Heartbeat por completo de este equipo:`n`n" +
        "  - El arranque automatico`n" +
        "  - Todos los archivos y mensajes guardados`n`n" +
        "No quedara ningun rastro. Continuar?",
        "Desinstalar Terminal Heartbeat",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning,
        [System.Windows.Forms.MessageBoxDefaultButton]::Button2
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    Write-Log "Uninstall confirmed by user"

    $startupFolder = [Environment]::GetFolderPath("Startup")
    $startupLnk = Join-Path $startupFolder "$projectName.lnk"
    $legacyVbs = Join-Path $startupFolder "$projectName.vbs"
    $helper = Join-Path $env:TEMP "$projectName-uninstall.ps1"
    $powershellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

    # Single-quoted literals in the helper; double any quote inside a path.
    function ConvertTo-PsLiteral { param([string]$Value) "'" + $Value.Replace("'", "''") + "'" }
    $qLnk    = ConvertTo-PsLiteral $startupLnk
    $qVbs    = ConvertTo-PsLiteral $legacyVbs
    $qFolder = ConvertTo-PsLiteral $script:dataFolder
    $qName   = ConvertTo-PsLiteral $projectName

    $helperScript = @"
Start-Sleep -Seconds 3
Remove-Item -LiteralPath $qLnk -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $qVbs -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $qName -Force -ErrorAction SilentlyContinue
schtasks /Delete /TN $qName /F | Out-Null
Remove-Item -LiteralPath $qFolder -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath `$PSCommandPath -Force -ErrorAction SilentlyContinue
"@

    try {
        $helperScript | Set-Content -Path $helper -Encoding UTF8 -Force
        Start-Process $powershellExe -ArgumentList `
            "-ExecutionPolicy","Bypass","-NoProfile","-WindowStyle","Hidden","-File","`"$helper`"" `
            -WindowStyle Hidden
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "No se pudo completar la desinstalacion automatica.`n`nError: $($_.Exception.Message)",
            "Terminal Heartbeat",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
}

# =============================================================================
#  NOTIFY ICON
# =============================================================================
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = $script:icons[1]
$notifyIcon.Visible = $true
$notifyIcon.Text = "Terminal Heartbeat"
Write-Log "Tray icon created"

# Context menu - only Close
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$contextMenu.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$contextMenu.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$contextMenu.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::System

$menuClose = New-Object System.Windows.Forms.ToolStripMenuItem
$menuClose.Text = "Cerrar"
$menuClose.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$menuClose.Add_Click({
    Write-Log "Closed by user"
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
[void]$contextMenu.Items.Add($menuClose)

[void]$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$menuUninstall = New-Object System.Windows.Forms.ToolStripMenuItem
$menuUninstall.Text = "Desinstalar"
$menuUninstall.ForeColor = [System.Drawing.Color]::FromArgb(220, 30, 50)
$menuUninstall.Add_Click({ Invoke-Uninstall })
[void]$contextMenu.Items.Add($menuUninstall)

$notifyIcon.ContextMenuStrip = $contextMenu

# Left-click = open popup
$notifyIcon.Add_MouseClick({
    param($s, $e)
    try {
        if ($e -and $e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Show-Popup
        }
    } catch {
        Write-Log "Show-Popup failed: $($_.Exception.Message)"
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

# First fetch runs after the icon is already visible, so a slow or missing
# network at boot can never delay or prevent the heart from appearing.
$initialFetchTimer = New-Object System.Windows.Forms.Timer
$initialFetchTimer.Interval = 3000
$initialFetchTimer.Add_Tick({
    $initialFetchTimer.Stop()
    Update-HeartData
})
$initialFetchTimer.Start()

# Refresh data every hour
$refreshTimer = New-Object System.Windows.Forms.Timer
$refreshTimer.Interval = 3600000
$refreshTimer.Add_Tick({ Update-HeartData })
$refreshTimer.Start()

# At logon the notification area may not accept icons yet, and an Explorer
# restart silently drops them. Re-assert visibility over the first minute.
$script:visibilityChecks = 0
$visibilityTimer = New-Object System.Windows.Forms.Timer
$visibilityTimer.Interval = 5000
$visibilityTimer.Add_Tick({
    $script:visibilityChecks++
    if (-not $notifyIcon.Visible) {
        Write-Log "Tray icon was not visible - re-registering (attempt $script:visibilityChecks)"
        $notifyIcon.Visible = $true
    }
    if ($script:visibilityChecks -ge 12) { $visibilityTimer.Stop() }
})
$visibilityTimer.Start()

# =============================================================================
#  RUN
# =============================================================================
Write-Log "Entering message loop"
[System.Windows.Forms.Application]::Run()
