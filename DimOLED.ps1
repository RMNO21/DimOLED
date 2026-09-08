Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$codeDefinition = @"
using System;
using System.Runtime.InteropServices;

public class WinInput {
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    public static uint GetIdleMs() {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)Marshal.SizeOf(lii);
        GetLastInputInfo(ref lii);
        return (uint)Environment.TickCount - lii.dwTime;
    }
}

public class AudioChecker {
    [ComImport]
    [Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    private class MMDeviceEnumeratorComObject { }

    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDeviceEnumerator {
        int NotImpl1();
        [PreserveSig]
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppDevice);
    }

    [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDevice {
        [PreserveSig]
        int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
    }

    [Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioMeterInformation {
        [PreserveSig]
        int GetPeakValue(out float pfPeak);
    }

    [Guid("77AA99A0-1BD6-440F-8AE0-48422A59A992"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionManager2 {
        int NotImpl1();
        int NotImpl2();
        [PreserveSig]
        int GetSessionEnumerator(out IAudioSessionEnumerator SessionEnum);
    }

    [Guid("E2F5EE11-2070-4E46-B16E-081537F9424F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionEnumerator {
        [PreserveSig]
        int GetCount(out int SessionCount);
        [PreserveSig]
        int GetSession(int SessionIndex, out IAudioSessionControl Session);
    }

    [Guid("F4B45649-7462-450A-A168-B528A8F32E03"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionControl {
        [PreserveSig]
        int GetState(out int pRetVal);
    }

    private static readonly Guid IID_IAudioMeterInformation = new Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064");
    private static readonly Guid IID_IAudioSessionManager2 = new Guid("77AA99A0-1BD6-440F-8AE0-48422A59A992");

    public static bool IsAudioPlaying() {
        try {
            var enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
            IMMDevice device;
            int hr = enumerator.GetDefaultAudioEndpoint(0, 1, out device); // eRender = 0, eMultimedia = 1
            if (hr != 0 || device == null) return false;

            // Check 1: Master audio peak meter > 0.001
            object oMeter;
            Guid iidMeter = IID_IAudioMeterInformation;
            hr = device.Activate(ref iidMeter, 23, IntPtr.Zero, out oMeter); // CLSCTX_ALL = 23
            if (hr == 0 && oMeter != null) {
                var meter = (IAudioMeterInformation)oMeter;
                float peak = 0;
                if (meter.GetPeakValue(out peak) == 0 && peak > 0.001f) {
                    return true;
                }
            }

            // Check 2: Active audio session state (AudioSessionStateActive = 1)
            object oMgr;
            Guid iidMgr = IID_IAudioSessionManager2;
            hr = device.Activate(ref iidMgr, 23, IntPtr.Zero, out oMgr);
            if (hr == 0 && oMgr != null) {
                var mgr = (IAudioSessionManager2)oMgr;
                IAudioSessionEnumerator sessionEnum;
                if (mgr.GetSessionEnumerator(out sessionEnum) == 0 && sessionEnum != null) {
                    int count = 0;
                    if (sessionEnum.GetCount(out count) == 0) {
                        for (int i = 0; i < count; i++) {
                            IAudioSessionControl session;
                            if (sessionEnum.GetSession(i, out session) == 0 && session != null) {
                                int state;
                                if (session.GetState(out state) == 0 && state == 1) { // 1 = AudioSessionStateActive
                                    return true;
                                }
                            }
                        }
                    }
                }
            }
        } catch { }
        return false;
    }
}
"@
Add-Type -TypeDefinition $codeDefinition -ErrorAction SilentlyContinue

$configDir = "$env:LOCALAPPDATA\DimOLED"
$configFile = "$configDir\config.ini"

function Load-Config {
    $cfg = @{
        TimeoutBatteryMin = 5
        TimeoutAcMin = 10
        DimBrightness = 1
        StartWithWindows = 1
        Enabled = 1
        IgnoreWhenAudioPlaying = 1
    }
    if (Test-Path $configFile) {
        Get-Content $configFile | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
                $p = $line.Split("=", 2)
                $k = $p[0].Trim()
                $v = $p[1].Trim()
                if ($cfg.ContainsKey($k)) {
                    $cfg[$k] = [int]$v
                }
            }
        }
    }
    return $cfg
}

function Save-Config($cfg) {
    $lines = @(
        "TimeoutBatteryMin=$($cfg.TimeoutBatteryMin)",
        "TimeoutAcMin=$($cfg.TimeoutAcMin)",
        "DimBrightness=$($cfg.DimBrightness)",
        "StartWithWindows=$($cfg.StartWithWindows)",
        "Enabled=$($cfg.Enabled)",
        "IgnoreWhenAudioPlaying=$($cfg.IgnoreWhenAudioPlaying)"
    )
    Set-Content -Path $configFile -Value $lines -Encoding ASCII

    $vbsPath = "$configDir\DimOLED_Silent.vbs"
    $vbsCode = "Set WshShell = CreateObject(""WScript.Shell"")`r`nWshShell.Run ""powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """"$configDir\DimOLED.ps1"""" -Silent"", 0, False"
    Set-Content -Path $vbsPath -Value $vbsCode -Encoding ASCII

    if ($cfg.StartWithWindows -eq 1) {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "DimOLED" -Value "wscript.exe `"$vbsPath`""
    } else {
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "DimOLED" -ErrorAction SilentlyContinue
    }
}

function Set-DisplayBrightness([int]$lvl) {
    try {
        $m = Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightnessMethods -ErrorAction SilentlyContinue
        if ($m) {
            $m | Invoke-CimMethod -MethodName WmiSetBrightness -Arguments @{ Timeout = 1; Brightness = $lvl } | Out-Null
        }
    } catch {}
}

function Get-DisplayBrightness {
    try {
        return (Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightness -ErrorAction SilentlyContinue).CurrentBrightness
    } catch { return 85 }
}

function Show-SettingsForm {
    $cfg = Load-Config

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "DimOLED - OLED Screen Protection Settings"
    $form.Size = New-Object System.Drawing.Size(460, 515)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

    $bg = [System.Drawing.Color]::FromArgb(30, 30, 42)
    $cardBg = [System.Drawing.Color]::FromArgb(40, 40, 56)
    $fg = [System.Drawing.Color]::FromArgb(235, 235, 245)
    $accent = [System.Drawing.Color]::FromArgb(99, 102, 241)

    $form.BackColor = $bg
    $form.ForeColor = $fg

    # Title
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "DimOLED - Display Protection Settings"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::White
    $lblTitle.Location = New-Object System.Drawing.Point(20, 18)
    $lblTitle.AutoSize = $true
    $form.Controls.Add($lblTitle)

    # Card 1: Timeouts
    $cardTimeouts = New-Object System.Windows.Forms.Panel
    $cardTimeouts.Location = New-Object System.Drawing.Point(20, 55)
    $cardTimeouts.Size = New-Object System.Drawing.Size(405, 115)
    $cardTimeouts.BackColor = $cardBg
    $form.Controls.Add($cardTimeouts)

    $lblCard1 = New-Object System.Windows.Forms.Label
    $lblCard1.Text = "Idle Time Before Dimming (Minutes):"
    $lblCard1.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $lblCard1.ForeColor = $accent
    $lblCard1.Location = New-Object System.Drawing.Point(15, 10)
    $lblCard1.AutoSize = $true
    $cardTimeouts.Controls.Add($lblCard1)

    $lblBat = New-Object System.Windows.Forms.Label
    $lblBat.Text = "On Battery:"
    $lblBat.Location = New-Object System.Drawing.Point(18, 42)
    $lblBat.AutoSize = $true
    $lblBat.ForeColor = $fg
    $cardTimeouts.Controls.Add($lblBat)

    $numBattery = New-Object System.Windows.Forms.NumericUpDown
    $numBattery.Location = New-Object System.Drawing.Point(270, 40)
    $numBattery.Width = 110
    $numBattery.Minimum = 1
    $numBattery.Maximum = 120
    $numBattery.Value = $cfg.TimeoutBatteryMin
    $numBattery.BackColor = $bg
    $numBattery.ForeColor = $fg
    $cardTimeouts.Controls.Add($numBattery)

    $lblAc = New-Object System.Windows.Forms.Label
    $lblAc.Text = "Plugged in (Charger):"
    $lblAc.Location = New-Object System.Drawing.Point(18, 75)
    $lblAc.AutoSize = $true
    $lblAc.ForeColor = $fg
    $cardTimeouts.Controls.Add($lblAc)

    $numAc = New-Object System.Windows.Forms.NumericUpDown
    $numAc.Location = New-Object System.Drawing.Point(270, 73)
    $numAc.Width = 110
    $numAc.Minimum = 1
    $numAc.Maximum = 120
    $numAc.Value = $cfg.TimeoutAcMin
    $numAc.BackColor = $bg
    $numAc.ForeColor = $fg
    $cardTimeouts.Controls.Add($numAc)

    # Card 2: Brightness
    $cardBright = New-Object System.Windows.Forms.Panel
    $cardBright.Location = New-Object System.Drawing.Point(20, 182)
    $cardBright.Size = New-Object System.Drawing.Size(405, 95)
    $cardBright.BackColor = $cardBg
    $form.Controls.Add($cardBright)

    $lblCard2 = New-Object System.Windows.Forms.Label
    $lblCard2.Text = "Dimmed Screen Brightness:"
    $lblCard2.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $lblCard2.ForeColor = $accent
    $lblCard2.Location = New-Object System.Drawing.Point(15, 10)
    $lblCard2.AutoSize = $true
    $cardBright.Controls.Add($lblCard2)

    $track = New-Object System.Windows.Forms.TrackBar
    $track.Location = New-Object System.Drawing.Point(15, 38)
    $track.Width = 310
    $track.Minimum = 1
    $track.Maximum = 50
    $track.Value = [Math]::Min(50, [Math]::Max(1, $cfg.DimBrightness))
    $track.TickFrequency = 5
    $cardBright.Controls.Add($track)

    $lblBVal = New-Object System.Windows.Forms.Label
    $lblBVal.Text = "$($track.Value)%"
    $lblBVal.Location = New-Object System.Drawing.Point(335, 42)
    $lblBVal.AutoSize = $true
    $lblBVal.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $lblBVal.ForeColor = [System.Drawing.Color]::FromArgb(74, 222, 128)
    $cardBright.Controls.Add($lblBVal)

    $track.Add_Scroll({ $lblBVal.Text = "$($track.Value)%" })

    # Card 3: Preferences
    $cardOptions = New-Object System.Windows.Forms.Panel
    $cardOptions.Location = New-Object System.Drawing.Point(20, 288)
    $cardOptions.Size = New-Object System.Drawing.Size(405, 108)
    $cardOptions.BackColor = $cardBg
    $form.Controls.Add($cardOptions)

    $chkAudio = New-Object System.Windows.Forms.CheckBox
    $chkAudio.Text = "Do not dim when audio / video is playing (media safe)"
    $chkAudio.Location = New-Object System.Drawing.Point(18, 10)
    $chkAudio.AutoSize = $true
    $chkAudio.Checked = ($cfg.IgnoreWhenAudioPlaying -eq 1)
    $chkAudio.ForeColor = $fg
    $cardOptions.Controls.Add($chkAudio)

    $chkStartup = New-Object System.Windows.Forms.CheckBox
    $chkStartup.Text = "Start automatically with Windows (silent in tray)"
    $chkStartup.Location = New-Object System.Drawing.Point(18, 42)
    $chkStartup.AutoSize = $true
    $chkStartup.Checked = ($cfg.StartWithWindows -eq 1)
    $chkStartup.ForeColor = $fg
    $cardOptions.Controls.Add($chkStartup)

    $chkEnabled = New-Object System.Windows.Forms.CheckBox
    $chkEnabled.Text = "Enable automatic OLED dimming protection"
    $chkEnabled.Location = New-Object System.Drawing.Point(18, 74)
    $chkEnabled.AutoSize = $true
    $chkEnabled.Checked = ($cfg.Enabled -eq 1)
    $chkEnabled.ForeColor = $fg
    $cardOptions.Controls.Add($chkEnabled)

    # Buttons
    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Save & Apply"
    $btnSave.Location = New-Object System.Drawing.Point(20, 415)
    $btnSave.Size = New-Object System.Drawing.Size(130, 38)
    $btnSave.BackColor = $accent
    $btnSave.ForeColor = [System.Drawing.Color]::White
    $btnSave.FlatStyle = "Flat"
    $btnSave.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnSave.Add_Click({
        $cfg.TimeoutBatteryMin = [int]$numBattery.Value
        $cfg.TimeoutAcMin = [int]$numAc.Value
        $cfg.DimBrightness = [int]$track.Value
        $cfg.StartWithWindows = if ($chkStartup.Checked) { 1 } else { 0 }
        $cfg.Enabled = if ($chkEnabled.Checked) { 1 } else { 0 }
        $cfg.IgnoreWhenAudioPlaying = if ($chkAudio.Checked) { 1 } else { 0 }
        Save-Config $cfg
        [System.Windows.Forms.MessageBox]::Show("Settings saved and applied successfully.", "DimOLED", "OK", "Information")
        $form.Close()
    })
    $form.Controls.Add($btnSave)

    $btnTest = New-Object System.Windows.Forms.Button
    $btnTest.Text = "Test Dim (3s)"
    $btnTest.Location = New-Object System.Drawing.Point(160, 415)
    $btnTest.Size = New-Object System.Drawing.Size(130, 38)
    $btnTest.BackColor = $cardBg
    $btnTest.ForeColor = $fg
    $btnTest.FlatStyle = "Flat"
    $btnTest.Add_Click({
        $orig = Get-DisplayBrightness
        Set-DisplayBrightness ([int]$track.Value)
        Start-Sleep -Seconds 3
        Set-DisplayBrightness $orig
    })
    $form.Controls.Add($btnTest)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Close"
    $btnClose.Location = New-Object System.Drawing.Point(300, 415)
    $btnClose.Size = New-Object System.Drawing.Size(125, 38)
    $btnClose.BackColor = $cardBg
    $btnClose.ForeColor = $fg
    $btnClose.FlatStyle = "Flat"
    $btnClose.Add_Click({ $form.Close() })
    $form.Controls.Add($btnClose)

    $form.TopMost = $true
    $form.Add_Shown({ $form.Activate() })
    $form.ShowDialog() | Out-Null
}

function Start-TrayService {
    $script:isDimmed = $false
    $script:origBright = Get-DisplayBrightness

    $tray = New-Object System.Windows.Forms.NotifyIcon
    $tray.Text = "DimOLED - OLED Screen Protection"
    $tray.Icon = [System.Drawing.SystemIcons]::Application
    $tray.Visible = $true

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $itemSettings = $menu.Items.Add("Settings...")
    $itemSettings.Add_Click({ Show-SettingsForm })

    $null = $menu.Items.Add("-")

    $itemDimNow = $menu.Items.Add("Dim Now")
    $itemDimNow.Add_Click({
        $c = Load-Config
        $script:origBright = Get-DisplayBrightness
        Set-DisplayBrightness $c.DimBrightness
        $script:isDimmed = $true
    })

    $itemRestore = $menu.Items.Add("Restore Brightness")
    $itemRestore.Add_Click({
        Set-DisplayBrightness $script:origBright
        $script:isDimmed = $false
    })

    $null = $menu.Items.Add("-")

    $itemExit = $menu.Items.Add("Exit")
    $itemExit.Add_Click({
        if ($script:isDimmed) { Set-DisplayBrightness $script:origBright }
        $tray.Visible = $false
        $tray.Dispose()
        [System.Windows.Forms.Application]::Exit()
        exit
    })

    $tray.ContextMenuStrip = $menu
    $tray.Add_DoubleClick({ Show-SettingsForm })
    $tray.Add_MouseClick({
        param($s, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Show-SettingsForm }
    })

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 500
    $script:checkConfigCount = 0
    $script:activeConfig = Load-Config

    $timer.Add_Tick({
        $script:checkConfigCount++
        if ($script:checkConfigCount -ge 6) {
            $script:checkConfigCount = 0
            $script:activeConfig = Load-Config
        }

        $cfg = $script:activeConfig
        if ($cfg.Enabled -ne 1) {
            if ($script:isDimmed) {
                Set-DisplayBrightness $script:origBright
                $script:isDimmed = $false
            }
            return
        }

        $isAc = ([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -eq [System.Windows.Forms.PowerLineStatus]::Online)
        $timeoutMin = if ($isAc) { $cfg.TimeoutAcMin } else { $cfg.TimeoutBatteryMin }
        $threshMs = [uint32]($timeoutMin * 60 * 1000)

        $idleMs = [WinInput]::GetIdleMs()
        $audioPlaying = if ($cfg.IgnoreWhenAudioPlaying -eq 1) { [AudioChecker]::IsAudioPlaying() } else { $false }

        # Debug logging every 5 seconds
        if ($script:checkConfigCount -eq 1) {
            try {
                $dbgMsg = "[$(Get-Date -Format 'HH:mm:ss')] isAc=$isAc, timeoutMin=$timeoutMin, idleSec=$([Math]::Round($idleMs/1000)), audio=$audioPlaying, dimmed=$($script:isDimmed)"
                [System.IO.File]::WriteAllText("$configDir\status.txt", $dbgMsg)
            } catch {}
        }

        if ($idleMs -ge $threshMs -and -not $script:isDimmed) {
            if (-not $audioPlaying) {
                $cur = Get-DisplayBrightness
                if ($cur -gt $cfg.DimBrightness) {
                    $script:origBright = $cur
                }
                Set-DisplayBrightness $cfg.DimBrightness
                $script:isDimmed = $true
            }
        }
        elseif (($idleMs -lt $threshMs -or $audioPlaying) -and $script:isDimmed) {
            $targetRestore = if ($script:origBright -gt $cfg.DimBrightness) { $script:origBright } else { 85 }
            Set-DisplayBrightness $targetRestore
            $script:isDimmed = $false
        }
    })
    $timer.Start()

    [System.Windows.Forms.Application]::Run()
}

if ($args -contains "-ShowSettings") {
    Show-SettingsForm
} elseif ($args -contains "-Silent") {
    Start-TrayService
} else {
    Show-SettingsForm
}
