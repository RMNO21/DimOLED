# 🌟 DimOLED

<p align="center">
  <b>Lightweight, Zero-Flicker Windows Background Utility for OLED Burn-In Prevention</b>
  <br/>
  <i>Developed with precision by <a href="https://github.com/RMNO21">RMNO21</a></i>
</p>

<p align="center">
  <a href="https://github.com/RMNO21/DimOLED/releases/latest"><img src="https://img.shields.io/github/v/release/RMNO21/DimOLED?style=for-the-badge&color=0078D4&logo=windows&logoColor=white" alt="Latest Release" /></a>
  <a href="https://github.com/RMNO21/DimOLED/stargazers"><img src="https://img.shields.io/github/stars/RMNO21/DimOLED?style=for-the-badge&color=dfb317" alt="Stars" /></a>
  <img src="https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D4?style=for-the-badge&logo=windows" alt="Platform" />
  <img src="https://img.shields.io/badge/Display-OLED%20%7C%20QD--OLED%20%7C%20WOLED-blueviolet?style=for-the-badge" alt="OLED Focus" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License" />
</p>

<p align="center">
  <a href="https://github.com/RMNO21/DimOLED/releases/latest">
    <img src="https://img.shields.io/badge/⬇️_DOWNLOAD_LATEST_RELEASE-v1.0.0-0078D4?style=for-the-badge&labelColor=000000" height="42" alt="Download DimOLED" />
  </a>
</p>

---

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

## ⭐ Support & Star

If DimOLED helps protect your OLED display, please consider **starring this repository**! It helps the project reach more users and motivates further development.

Contributions, bug reports, and suggestions are welcome via [GitHub Issues](https://github.com/RMNO21/DimOLED/issues).

---

## License

MIT License. Feel free to use and modify!
