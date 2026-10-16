# Terminal Heartbeat v2.0

> *A heartbeat that crosses the screen to reach you.*

A discreet system tray application for Windows that displays an animated heart icon. Click it to see a personalized greeting and a random romantic message. Messages are managed remotely through an admin panel hosted on Vercel.

## Features

- **Animated Heart Icon** — A pulsing red heart in the Windows system tray (32x32, drawn with GDI+).
- **Click-to-Reveal Popup** — Styled popup (black/red theme) with time-aware greetings and random messages.
- **Remote Message Management** — Messages and greetings live on Vercel; update them anytime from anywhere.
- **Admin Panel** — Web UI to add, edit, and delete messages and greetings per time period.
- **Time-Aware Greetings** — Detects morning, afternoon, or night and shows the appropriate greeting.
- **Offline Fallback** — Caches messages locally; works even without internet.
- **Zero-Dependency** — Runs natively on Windows 10/11 PowerShell. No admin rights required.
- **Auto-Startup** — Starts silently on every Windows login.
- **One-Click Uninstall** — Right-click the heart → **Desinstalar** removes everything, no traces.

## Architecture

```
PC (PowerShell)                          Vercel (Free Tier)
┌──────────────────────┐                ┌──────────────────────┐
│  System Tray Icon    │   HTTP GET     │  GET /api/messages   │
│  (NotifyIcon)        │ ──────────────>│  GET /api/greetings  │
│                      │                │                      │
│  Click → Popup       │                │  Admin Panel /admin  │
│  Cache → cache.json  │                │  Storage: Vercel KV  │
└──────────────────────┘                └──────────────────────┘
```

## Setup

### 1. Deploy the Backend

1. Fork or clone this repository.
2. In the [Vercel Dashboard](https://vercel.com), create a new project from the `web/` directory.
3. Go to **Storage** → **Create Database** → **KV** → link it to the project.
4. Go to **Settings** → **Environment Variables** → add `ADMIN_PASSWORD` with a secure password.
5. Deploy. Note the URL (e.g., `https://terminal-heartbeat.vercel.app`).

### 2. Seed Messages

1. Visit `https://your-deployment.vercel.app/admin`.
2. Log in with your admin password.
3. Add messages (the random phrases she'll see).
4. Add greetings for each time period (morning, afternoon, night).

### 3. Install on the Target PC

1. Open `install_heart.ps1` and update the `$apiUrl` variable with your Vercel URL:
   ```powershell
   $apiUrl = "https://your-deployment.vercel.app"
   ```
2. Copy `install_heart.ps1` to the target computer (USB, email, etc.).
3. Right-click → **Run with PowerShell**.
4. The installer will:
   - Create files in `%LOCALAPPDATA%\TerminalHeartbeat\`
   - Add a startup shortcut for the current user
   - Optionally launch immediately

> **Note:** If Windows SmartScreen blocks the script, right-click the file → Properties → check **Unblock**.

## Updating

To update to a newer version, simply **run the installer again**. It will:

1. Kill any running instance of Terminal Heartbeat.
2. Remove all previous files and the old startup shortcut.
3. Install the new version from scratch.

No manual cleanup needed. This works across any version (v1.0 → v2.0, v2.0 → v2.1, etc.).

## Uninstallation

**From the tray icon (easiest — no files or terminal needed):**

Right-click the heart → **Desinstalar** → confirm. Everything is removed immediately.

Because the app runs from the folder it has to delete, the cleanup is handed to a
small detached PowerShell helper that waits for the process to exit, removes every
trace, and then deletes itself.

**From the installer:**

```powershell
powershell -ExecutionPolicy Bypass -File install_heart.ps1 -Uninstall
```

Either method removes:
- The auto-start VBS from the Startup folder
- The data folder (`%LOCALAPPDATA%\TerminalHeartbeat\`), including cache and log
- Legacy traces from older versions (startup shortcut, `HKCU\Run` entry, scheduled task)
- The running process

**Manual uninstall** (last resort):

1. Close the heart (right-click tray icon → Cerrar).
2. Press `Win + R`, type `shell:startup`, delete `TerminalHeartbeat.lnk`.
3. Press `Win + R`, type `%localappdata%`, delete the `TerminalHeartbeat` folder.

## Updating Messages Remotely

1. Go to your Vercel deployment `/admin`.
2. Log in with your password.
3. Add, edit, or delete messages and greetings.
4. The app fetches fresh data every hour automatically.

## Customization

### API URL
Edit the `$apiUrl` variable at the top of `install_heart.ps1` before running it.

### Time Periods
| Period    | Hours       | Default Greeting         |
|-----------|-------------|--------------------------|
| Morning   | 6:00–11:59  | Buenos dias, mi amor     |
| Afternoon | 12:00–19:59 | Buenas tardes, preciosa  |
| Night     | 20:00–5:59  | Buenas noches, mi vida   |

### Popup Style
The popup uses a dark theme (background `#121212`, red accents `#dc1e32`, white text) with rounded corners and a subtle red border glow.

## Startup Behavior

Auto-start uses a standard `.lnk` shortcut in the user's Startup folder
(`shell:startup`) that launches `powershell.exe` with `-WindowStyle Hidden`.

A shortcut is used rather than a `.vbs` launcher because it depends on nothing beyond
PowerShell itself. A `.vbs` needs Windows Script Host, which some machines disable by
policy. A bare `.ps1` is not an option at all: Windows maps `.ps1` to *Edit*, so one
placed in the Startup folder opens in Notepad instead of running.

Two details matter for it to work reliably at logon:

- **25-second delay.** At logon the notification area does not accept tray icons for the
  first few seconds; an icon registered too early is silently dropped and never appears.
  The shortcut passes `-Startup`, which makes the client wait before registering. Launching
  without that switch starts immediately, which is what the installer does.
- **The icon is created before any network call.** Messages load from the local cache
  first, and the API fetch happens 3 seconds later on a timer. A slow or absent network
  at boot can delay the *messages*, never the heart itself.

If the heart does not appear, check `%LOCALAPPDATA%\TerminalHeartbeat\startup.log` — it
records each launch, whether the cache or the API was used, and any fetch failure.

> **Note:** New tray icons land in the overflow area in Windows 11. Click the `^` arrow
> next to the clock and drag the heart onto the taskbar to keep it visible.

## Technical Details

- **Client**: PowerShell 5.1 + .NET WinForms (`System.Windows.Forms.NotifyIcon`)
- **Heart Icon**: Parametric curve (`x=16sin³t`, `y=13cos(t)-5cos(2t)-2cos(3t)-cos(4t)`) rendered at 32x32 via GDI+
- **Animation**: 3 frames at scales 0.82, 1.0, 1.10 cycled at 500ms (WinForms Timer)
- **Console Hiding**: P/Invoke `kernel32.GetConsoleWindow` + `user32.ShowWindow(hwnd, SW_HIDE)`
- **Backend**: Next.js 14 App Router + Vercel KV
- **Auth**: Bearer token matching `ADMIN_PASSWORD` env var
- **HTTP**: `WebClient` subclass with UTF-8 encoding and an 8s timeout — PowerShell 5.1's
  `Invoke-RestMethod` decodes UTF-8 responses as Latin-1, mangling accents and emoji
- **Single instance**: named `Mutex`, so overlapping launches exit instead of stacking icons
- **Encoding**: both scripts are pure ASCII. PowerShell 5.1 reads BOM-less files as ANSI,
  which turns a UTF-8 em dash into a smart quote and breaks string parsing — keeping the
  sources ASCII makes them immune to however the files are copied

## Disclaimer

This script is intended as a harmless, loving gesture. It runs entirely in user-space and does not require administrative privileges. It does not modify system settings, registry (beyond user-level startup), or any system files.
