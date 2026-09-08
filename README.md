# DimOLED

**DimOLED** is a lightweight, zero-flicker background utility for Windows designed to protect OLED screens from burn-in and save power by automatically dimming the physical display brightness when the system is idle.

Unlike traditional screensavers or lock screens, DimOLED:
- **Dims the actual hardware display brightness** (down to 1% or whatever level you choose) using Windows WMI monitor brightness controls.
- **Keeps your desktop visible** without black screen overlays or desktop switches.
- **Doesn't interrupt video playback or background tasks** — it restores brightness instantly as soon as mouse or keyboard input is detected.
- **Smart App Control (SAC) Friendly**: Runs through standard signed Windows host components with zero third-party unsigned binaries.

---

## Features

- **Separate Idle Timeouts**:
  - Configurable timeout for **AC Power (Plugged in)** (e.g. 10 minutes).
  - Configurable timeout for **Battery Power** (e.g. 5 minutes).
- **Customizable Dim Level**: Set the dim level down to **1%** for maximum OLED pixel protection without turning the display completely off.
- **Instant Restore**: Returns display to previous brightness level immediately on any mouse move or key press.
- **Zero Distraction**: Runs silently in the background via VBScript runner with no command prompts or taskbar windows.
- **Optional Settings UI**: Includes a dark-mode Settings UI to adjust timings, brightness percentage, and auto-start preferences.

---

## Configuration

The default configuration file (`%LOCALAPPDATA%\DimOLED\config.ini`) looks like this:

```ini
TimeoutBatteryMin=5
TimeoutAcMin=10
DimBrightness=1
StartWithWindows=1
Enabled=1
IgnoreWhenAudioPlaying=1
```

| Setting | Default | Description |
|---|---|---|
| `TimeoutBatteryMin` | `5` | Inactivity minutes before dimming on battery |
| `TimeoutAcMin` | `10` | Inactivity minutes before dimming on AC power |
| `DimBrightness` | `1` | Brightness level (1–100%) when dimmed |
| `StartWithWindows` | `1` | Automatically launch at Windows login (1 = yes, 0 = no) |
| `Enabled` | `1` | Master toggle to enable or disable dimming |
| `IgnoreWhenAudioPlaying`| `1` | Prevent dimming when audio/video is playing (Media Safe) |

---

## Quick Installation

1. Clone or download this repository.
2. Run `install.bat`.
3. DimOLED will copy its scripts to `%LOCALAPPDATA%\DimOLED`, set up startup in Windows Registry, and start running in the background.

---

## Manual Run / Settings

- **Run in background (Silent)**:
  ```cmd
  wscript.exe "%LOCALAPPDATA%\DimOLED\DimOLED_Silent.vbs"
  ```

- **Open Settings UI**:
  ```cmd
  powershell.exe -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\DimOLED\DimOLED.ps1" -ShowSettings
  ```

---

## License

MIT License. Feel free to use and modify!
