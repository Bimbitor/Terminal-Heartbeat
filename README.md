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
- **Clean Uninstall** — Removes everything without leaving traces.

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

To completely remove Terminal Heartbeat with no traces left:

```powershell
powershell -ExecutionPolicy Bypass -File install_heart.ps1 -Uninstall
```

This removes:
- The startup shortcut
- The data folder (`%LOCALAPPDATA%\TerminalHeartbeat\`)
- Kills the running process (if active)

**Manual uninstall** (if you don't have the installer):

1. Close the heart (right-click tray icon → Cerrar).
2. Press `Win + R`, type `shell:startup`, delete the `TerminalHeartbeat` shortcut.
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

## Technical Details

- **Client**: PowerShell 5.1 + .NET WinForms (`System.Windows.Forms.NotifyIcon`)
- **Heart Icon**: Parametric curve (`x=16sin³t`, `y=13cos(t)-5cos(2t)-2cos(3t)-cos(4t)`) rendered at 32x32 via GDI+
- **Animation**: 3 frames at scales 0.82, 1.0, 1.10 cycled at 500ms (WinForms Timer)
- **Console Hiding**: P/Invoke `kernel32.GetConsoleWindow` + `user32.ShowWindow(hwnd, SW_HIDE)`
- **Backend**: Next.js 14 App Router + Vercel KV
- **Auth**: Bearer token matching `ADMIN_PASSWORD` env var

## Disclaimer

This script is intended as a harmless, loving gesture. It runs entirely in user-space and does not require administrative privileges. It does not modify system settings, registry (beyond user-level startup), or any system files.
