# ❤️ Terminal-Heartbeat

> *"Code is my love language."*

## 📖 Overview

**Terminal-Heartbeat** is a romantic automation script designed as a unique gift for a developer or tech-savvy partner. It acts as a "digital greeting card" that installs itself on a Windows computer to run automatically upon startup.

Every time the special person turns on their PC, a terminal window pops up displaying an **animated ASCII heart** and a randomized message selected from a customizable list of motivational quotes, romantic lines, and inside jokes. It serves as a daily reminder that someone is thinking of them before they start their day.

## ✨ Features

* **Heart Animation:** A beating ASCII heart loop running in the console.
* **Daily Random Message:** Displays a different quote from a customizable list every time it runs.
* **Auto-Startup:** Automatically creates a shortcut in the Windows Startup folder using PowerShell objects.
* **Zero-Dependencies:** Runs natively on Windows; no external software installation required.

## 🚀 Installation

This script is meant to be run once on the target computer to set up the background task.

### Prerequisites
* Windows 10 or Windows 11.
* PowerShell (Standard on Windows).

### Steps to Install

1.  **Clone or Download:** Download the `install_heart.ps1` file from this repository.
2.  **Customize the Messages (Highly Recommended):**
    * Open `install_heart.ps1` with a text editor (VS Code, Notepad++, or Notepad).
    * Locate the `$mensajes` (messages) array.
    * Replace the example phrases with your own inside jokes, romantic notes, or words of encouragement.
    * *Tip: Personalizing this section is what makes the gift special.*
3.  **Run the Installer:**
    * Right-click on `install_heart.ps1`.
    * Select **"Run with PowerShell"**.
4.  **Verification:**
    * The script will configure the hidden folder and create the startup shortcut.
    * You can restart the computer to test it, or it will simply appear the next time the system boots up.

## ⚙️ How it Works

1.  **Environment Setup:** The script creates a dedicated folder in the user's local AppData directory (e.g., `%USERPROFILE%\AppData\Local\YourProjectName`).
2.  **Script Generation:** It generates a standalone script containing the animation logic and your custom messages inside that folder.
3.  **Persistence:** It creates a standard `.lnk` shortcut in the Windows **Startup** folder. This ensures the window opens automatically upon user login.

## 📝 Customization Guide

To tailor the experience, edit the `$mensajes` section in the source code before running the installer.

**Example structure:**

```powershell
$mensajes = @(
    "🍆 The only pressure that matters is mine.",
    "☕ Remember, there is never enough coffee.",
    "🚀 Today will be an amazing day, just like you.",
    "💪 You are stronger than you think.",
    "❤️ I love you.",
    "🕶️ If you see me smiling, I probably broke production."
)
```
## 🗑️ Uninstallation

If you wish to remove the program completely, follow these steps:

1.  **Stop the script:**
    * Close the PowerShell window displaying the heart.

2.  **Remove the Startup Shortcut:**
    * Press `Win + R`, type `shell:startup`, and press **Enter**.
    * Delete the shortcut file created by the script.

3.  **Remove the Data Files:**
    * Press `Win + R`, type `%localappdata%`, and press **Enter**.
    * Locate the project folder (based on the name defined in the script) and delete it.

## ⚠️ Disclaimer

This script is intended as a harmless, loving gesture. It runs in user-space and does not require administrative privileges to run (though it might require permission to execute scripts depending on the computer's security policy).

> **Note:** If execution is blocked, you may need to open PowerShell as Administrator and run `Set-ExecutionPolicy RemoteSigned` temporarily to allow the installation.

