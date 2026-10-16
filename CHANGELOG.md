# Changelog

All notable changes to this project are documented here.

## [v2.0] - 2026-10-16

A full rewrite of the client, from a visible terminal window to a discreet system tray
icon, plus a hosted backend so messages can be changed without touching the target PC.

### Added

- **System tray client.** An animated heart drawn with GDI+ from a parametric curve,
  pulsing across three frames. Replaces the v1.0 terminal window, which was visible to
  anyone nearby.
- **Click-to-reveal popup.** A borderless dark-themed window with rounded corners, a
  time-aware greeting and a random message.
- **Vercel backend.** Next.js 14 App Router with Vercel KV storing messages and
  greetings, served from `/api/messages` and `/api/greetings`.
- **Admin panel** at `/admin` for adding, editing and deleting messages and greetings,
  with multiline support and a live preview of the popup.
- **Time-aware greetings** for morning, afternoon and night, each with its own editable
  list.
- **Offline fallback.** Messages are cached locally and fall back to built-in defaults,
  so the heart works without a network.
- **Uninstall from the tray.** Right-click → *Desinstalar* removes every trace. Because
  the client runs from the folder it has to delete, cleanup is delegated to a detached
  helper that waits for the process to exit and then deletes itself.
- **Startup diagnostics.** `startup.log` records each launch, the data source used and
  any recovered error.

### Fixed

- **Autostart never ran.** Two independent causes: the API fetch ran before the tray icon
  was created, so a slow network at boot blocked startup entirely; and the launcher
  started PowerShell immediately at logon, before the notification area accepts icons, so
  the icon was silently dropped. The icon is now created first from cache, and the
  startup path waits 25 seconds.
- **UTF-8 mangled accents and emoji.** PowerShell 5.1's `Invoke-RestMethod` decodes UTF-8
  responses as Latin-1, turning `corazón` into `corazÃ³n`. Replaced with a `WebClient`
  subclass using explicit UTF-8 and an 8-second timeout.
- **Emoji in greetings rendered as tofu boxes.** The greeting label used `Segoe UI`, which
  has no emoji glyphs, while the message label already used `Segoe UI Emoji`.
- **A drawing error could kill the application.** The popup's Paint handler read
  `$e.Graphics` unconditionally; a reentrant event could leave it unbound, raising an
  unhandled exception that surfaced as a .NET crash dialog. Drawing is now isolated and
  UI-thread exceptions are logged instead of fatal.
- **Scripts could break depending on how they were copied.** Both contained a UTF-8 em
  dash, and PowerShell 5.1 reads BOM-less files as ANSI, turning it into a smart quote
  that terminates string literals early. The sources are now pure ASCII.
- **Duplicate instances.** A named mutex ensures overlapping launches exit instead of
  stacking tray icons.

### Changed

- Autostart moved from a `.vbs` launcher to a standard `.lnk` shortcut, removing the
  dependency on Windows Script Host, which some machines disable by policy. The installer
  still cleans up `.vbs`, `HKCU\Run` and scheduled-task entries left by earlier attempts.
- The installer always removes any previous version before installing, so upgrading is
  just a matter of running it again.

## [v1.0] - 2026-09

The original: a PowerShell script that opened a terminal window at logon with an ASCII
heart animation and one of twelve hardcoded messages.

- ASCII-art heart animated across frames in a console window
- Twelve messages baked into the installer, chosen at random per session
- Autostart via a Startup folder shortcut
- No network dependency, no admin rights

Its twelve messages were migrated into the v2.0 backend and are still in rotation.

[v2.0]: https://github.com/Bimbitor/Terminal-Heartbeat/releases/tag/v2.0
[v1.0]: https://github.com/Bimbitor/Terminal-Heartbeat/releases/tag/v1.0
