# ==============================================================================
# НАЗВА: Універсальний Steam_Launcher.ps1 (v 3.0 - Perfected UI & Logic)
# ОПИС: Розумна картотека ігор, автозавершення, вихід в один клік через трей.
# КОДУВАННЯ: Обов'язково зберегти як "UTF-8 with BOM"
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------------------------
# БЛОК 1: СУЧАСНІ ЕЛЕМЕНТИ ІНТЕРФЕЙСУ (C# 5.0 Сумісний)
# ------------------------------------------------------------------------------
if (-not ([System.Management.Automation.PSTypeName]"SteamUITheme").Type) {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    using System.Drawing;
    using System.Drawing.Drawing2D;
    using System.Windows.Forms;

    public class SteamUITheme {
        [DllImport("user32.dll")]
        public static extern bool SetProcessDPIAware();

        [DllImport("dwmapi.dll")]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        public static void StyleTitleBar(IntPtr hwnd, Color bgColor, Color textColor) {
            int trueVal = 1;
            DwmSetWindowAttribute(hwnd, 19, ref trueVal, sizeof(int));
            DwmSetWindowAttribute(hwnd, 20, ref trueVal, sizeof(int));
                
            int bgRef = bgColor.R | (bgColor.G << 8) | (bgColor.B << 16);
            DwmSetWindowAttribute(hwnd, 35, ref bgRef, sizeof(int));

            int textRef = textColor.R | (textColor.G << 8) | (textColor.B << 16);
            DwmSetWindowAttribute(hwnd, 36, ref textRef, sizeof(int));
        }
    }

    public class RoundedButton : Control {
        private int _cornerRadius = 8;
        private Color _normalColor = Color.Gray;
        private Color _hoverColor = Color.LightGray;
        private bool _isHovered = false;

        public int CornerRadius { get { return _cornerRadius; } set { _cornerRadius = value; Invalidate(); } }
        public Color NormalColor { get { return _normalColor; } set { _normalColor = value; Invalidate(); } }
        public Color HoverColor { get { return _hoverColor; } set { _hoverColor = value; Invalidate(); } }

        public RoundedButton() {
            this.SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.Selectable | ControlStyles.StandardClick, true);
        }

        protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); _isHovered = true; Invalidate(); }
        protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); _isHovered = false; Invalidate(); }

        protected override void OnPaint(PaintEventArgs pevent) {
            pevent.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            pevent.Graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            
            Color bgColor = this.Parent != null ? this.Parent.BackColor : Color.FromArgb(36, 38, 43);
            pevent.Graphics.Clear(bgColor);
            
            Rectangle rect = new Rectangle(0, 0, this.Width - 1, this.Height - 1);
            GraphicsPath path = new GraphicsPath();
            float d = CornerRadius * 2F;
            path.AddArc(rect.X, rect.Y, d, d, 180, 90);
            path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90);
            path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
            path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            
            Color drawColor = _isHovered ? HoverColor : NormalColor;
            using (SolidBrush brush = new SolidBrush(drawColor)) { pevent.Graphics.FillPath(brush, path); }
            TextRenderer.DrawText(pevent.Graphics, this.Text, this.Font, rect, this.ForeColor, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }
    }

    public class ModernToggle : CheckBox {
        private Color _onColor = Color.FromArgb(0, 120, 212);
        private Color _offColor = Color.FromArgb(70, 70, 70);
        private Color _thumbColor = Color.White;
        
        private float _animPos = 0f;
        private Timer _animTimer;
        private bool _isHovered = false;

        public Color OnColor { get { return _onColor; } set { _onColor = value; Invalidate(); } }
        public Color OffColor { get { return _offColor; } set { _offColor = value; Invalidate(); } }
        public Color ThumbColor { get { return _thumbColor; } set { _thumbColor = value; Invalidate(); } }

        public ModernToggle() {
            this.SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
            this.AutoSize = false;
            this.Size = new Size(80, 48); 
            this.Cursor = Cursors.Default;
            
            _animTimer = new Timer();
            _animTimer.Interval = 15;
            _animTimer.Tick += new EventHandler(OnAnimTick);
        }

        private void OnAnimTick(object sender, EventArgs e) {
            float target = this.Checked ? 1.0f : 0.0f;
            if (Math.Abs(_animPos - target) < 0.02f) {
                _animPos = target;
                _animTimer.Stop();
            } else {
                _animPos += (target - _animPos) * 0.3f; // Швидкість анімації
            }
            this.Invalidate();
        }

        protected override void OnCheckedChanged(EventArgs e) {
            base.OnCheckedChanged(e);
            _animTimer.Start();
        }

        protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); _isHovered = true; Invalidate(); }
        protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); _isHovered = false; Invalidate(); }

        protected override void OnPaint(PaintEventArgs pevent) {
            pevent.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            pevent.Graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            
            Color bgColor = this.Parent != null ? this.Parent.BackColor : Color.FromArgb(41, 47, 59);
            pevent.Graphics.Clear(bgColor);

            Rectangle rect = new Rectangle(1, 1, this.Width - 3, this.Height - 3);
            GraphicsPath path = GetRoundedPath(rect);

            using (SolidBrush brush = new SolidBrush(this.Checked ? _onColor : _offColor)) {
                pevent.Graphics.FillPath(brush, path);
            }

            if (_isHovered) {
                using (Pen pen = new Pen(Color.FromArgb(80, 255, 255, 255), 2f)) {
                    pevent.Graphics.DrawPath(pen, path);
                }
            } else {
                using (Pen pen = new Pen(Color.FromArgb(40, 0, 0, 0), 1f)) {
                    pevent.Graphics.DrawPath(pen, path);
                }
            }

            int thumbMargin = 4;
            int thumbSize = this.Height - (thumbMargin * 2) - 2;
            int startX = thumbMargin + 1;
            int endX = this.Width - thumbSize - thumbMargin - 2;

            float currentX = startX + (endX - startX) * _animPos;

            float overshootFactor = 6.0f;
            if (_animPos > 0.7f && this.Checked) currentX += overshootFactor * (1.0f - _animPos);
            if (_animPos < 0.3f && !this.Checked) currentX -= overshootFactor * _animPos;

            using (SolidBrush thumbBrush = new SolidBrush(_thumbColor)) {
                pevent.Graphics.FillEllipse(thumbBrush, currentX, thumbMargin + 1, thumbSize, thumbSize);
            }
            
            path.Dispose();
        }

        private GraphicsPath GetRoundedPath(Rectangle r) {
            GraphicsPath gp = new GraphicsPath();
            int d = r.Height;
            gp.AddArc(r.X, r.Y, d, d, 90, 180);
            gp.AddArc(r.Right - d, r.Y, d, d, -90, 180);
            gp.CloseFigure();
            return gp;
        }
    }

    public class WinAPIKeyboard {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
        public static void ToggleHDR() {
            byte VK_LWIN = 0x5B; byte VK_MENU = 0x12; byte VK_B = 0x42; uint KEYEVENTF_KEYUP = 0x0002;
            keybd_event(VK_LWIN, 0, 0, UIntPtr.Zero); keybd_event(VK_MENU, 0, 0, UIntPtr.Zero); keybd_event(VK_B, 0, 0, UIntPtr.Zero);
            keybd_event(VK_B, 0, KEYEVENTF_KEYUP, UIntPtr.Zero); keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, UIntPtr.Zero); keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        }
    }
"@ -ReferencedAssemblies "System.Windows.Forms", "System.Drawing"
}

[SteamUITheme]::SetProcessDPIAware() | Out-Null

# ------------------------------------------------------------------------------
# БЛОК 2: РОЗУМНА ОБРОБКА АРГУМЕНТІВ ТА ПАРСИНГ НАЗВ
# ------------------------------------------------------------------------------
if ($args.Count -eq 0) { exit }

$exe = $args[0] -replace '^"|"$', ''
$gameArgsString = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] -join " " } else { "" }
$gameDir = Split-Path -Parent $exe
$exeName = [System.IO.Path]::GetFileNameWithoutExtension($exe)

$parentFolder = Split-Path $gameDir -Leaf
if ($parentFolder -match "(?i)^(bin|binaries|win32|win64|x64)$") {
    $parentFolder = Split-Path (Split-Path $gameDir -Parent) -Leaf
}

$gameDisplayName = $parentFolder
$configKey = "$parentFolder\$exeName"

# ------------------------------------------------------------------------------
# БЛОК 3: ІНДИВІДУАЛЬНА КОНФІГУРАЦІЯ
# ------------------------------------------------------------------------------
$configFile = Join-Path $PSScriptRoot "Steam_Launcher_Configs.json"
$configMap = @{}

if (Test-Path $configFile) {
    try {
        $jsonContent = Get-Content $configFile -Raw -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($jsonContent)) {
            $json = $jsonContent | ConvertFrom-Json
            if ($json -is [System.Management.Automation.PSCustomObject]) {
                foreach ($prop in $json.psobject.properties) {
                    $configMap[$prop.Name] = @{
                        Use2K = [bool]$prop.Value.Use2K
                        UseClone = [bool]$prop.Value.UseClone
                        UseHDR = [bool]$prop.Value.UseHDR
                    }
                }
            }
        }
    } catch {}
}

if (-not $configMap.Contains($configKey)) {
    $configMap[$configKey] = @{ Use2K = $true; UseClone = $false; UseHDR = $false }
}

$currentConfig = $configMap[$configKey]
if (-not $currentConfig.Use2K) { $currentConfig.UseClone = $false }
if ($currentConfig.UseClone) { $currentConfig.UseHDR = $false; $currentConfig.Use2K = $true }

# ------------------------------------------------------------------------------
# БЛОК 4: ДАШБОРД НАЛАШТУВАНЬ ЗАПУСКУ
# ------------------------------------------------------------------------------
function Show-SettingsDashboard {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Параметри запуску $gameDisplayName"
    $form.Size = New-Object System.Drawing.Size(800, 512)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    
    $form.MaximizeBox = $false 
    $form.MinimizeBox = $false
    
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    
    $themeColor = [System.Drawing.Color]::FromArgb(41, 47, 59)
    $titleTextColor = [System.Drawing.Color]::Gray
    $form.BackColor = $themeColor
    $form.ForeColor = [System.Drawing.Color]::LightGray
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $form.TopMost = $true
    $form.ShowIcon = $false

    [SteamUITheme]::StyleTitleBar($form.Handle, $themeColor, $titleTextColor)

    $contentPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $contentPanel.Dock = 'Fill'
    $contentPanel.FlowDirection = 'TopDown'
    $contentPanel.Padding = New-Object System.Windows.Forms.Padding(128, 50, 40, 0)
    $contentPanel.WrapContents = $false

    function Add-ToggleRow($labelText, $initialState) {
        $row = New-Object System.Windows.Forms.Panel
        $row.Width = 680
        $row.Height = 50 
        $row.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 24)

        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $labelText
        $lbl.AutoSize = $true
        $lbl.Location = New-Object System.Drawing.Point(0, 0)

        $toggle = New-Object ModernToggle
        $toggle.Location = New-Object System.Drawing.Point(480, 0)
        $toggle.Checked = $initialState

        $row.Controls.Add($toggle) | Out-Null
        $row.Controls.Add($lbl) | Out-Null
        $contentPanel.Controls.Add($row) | Out-Null
        return $toggle
    }

    $tgl2K = Add-ToggleRow "Перемкнути у QHD" $currentConfig.Use2K
    $tglClone = Add-ToggleRow "Увімкнути дублювання екранів" $currentConfig.UseClone
    $tglHDR = Add-ToggleRow "Увімкнути HDR" $currentConfig.UseHDR

    $tgl2K.Add_CheckedChanged({
        if (-not $tgl2K.Checked) { $tglClone.Checked = $false }
    })

    $tglClone.Add_CheckedChanged({
        if ($tglClone.Checked) {
            if (-not $tgl2K.Checked) { $tgl2K.Checked = $true }
            if ($tglHDR.Checked) { $tglHDR.Checked = $false }
        }
    })

    $tglHDR.Add_CheckedChanged({
        if ($tglHDR.Checked) {
            if ($tglClone.Checked) { $tglClone.Checked = $false }
        }
    })

    $btnPanel = New-Object System.Windows.Forms.Panel
    $btnPanel.Dock = 'Bottom'
    $btnPanel.Height = 160
    $btnPanel.BackColor = [System.Drawing.Color]::FromArgb(36, 38, 43)

    $btnLaunch = New-Object RoundedButton
    $btnLaunch.Text = "ГРАТИ"
    $btnLaunch.Size = New-Object System.Drawing.Size(352, 96)
    $btnLaunch.Location = New-Object System.Drawing.Point(224, 32) 
    $btnLaunch.ForeColor = [System.Drawing.Color]::White
    $btnLaunch.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
    $btnLaunch.NormalColor = [System.Drawing.Color]::FromArgb(118, 197, 79) 
    $btnLaunch.HoverColor = [System.Drawing.Color]::FromArgb(137, 211, 71) 

    $btnLaunch.Add_Click({
        $currentConfig.Use2K = $tgl2K.Checked
        $currentConfig.UseClone = $tglClone.Checked
        $currentConfig.UseHDR = $tglHDR.Checked
        
        try {
            $configMap | ConvertTo-Json -Depth 3 | Set-Content $configFile -Encoding UTF8
        } catch {}

        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    })

    $btnPanel.Controls.Add($btnLaunch) | Out-Null
    $form.Controls.Add($contentPanel) | Out-Null
    $form.Controls.Add($btnPanel) | Out-Null

    $form.AcceptButton = $btnLaunch

    $form.Add_Shown({
        $SW_SHOW = 5
        [SteamUITheme]::ShowWindow($form.Handle, $SW_SHOW) | Out-Null
        [SteamUITheme]::SetForegroundWindow($form.Handle) | Out-Null
        $form.Activate()
        $form.BringToFront()
    })

    $result = $form.ShowDialog()
    $form.Dispose()
    return $result
}

if ((Show-SettingsDashboard) -ne 'OK') { exit }

# ------------------------------------------------------------------------------
# БЛОК 5: ЗАСТОСУВАННЯ ПАРАМЕТРІВ ТА ЗАПУСК ГРИ
# ------------------------------------------------------------------------------
function Wait-DisplayResolution([int]$TargetWidth) {
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt 15) {
        $vc = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($vc.CurrentHorizontalResolution -eq $TargetWidth) { return }
        Start-Sleep -Milliseconds 500
    }
}

$script2K = Join-Path $PSScriptRoot "Switch_5K_to_2K.ps1"
$script5K = Join-Path $PSScriptRoot "Switch_2K_to_5K.ps1"

if ($currentConfig.Use2K -and (Test-Path $script2K)) {
    & $script2K
    Wait-DisplayResolution 2560
}

if ($currentConfig.UseClone) {
    & "C:\Windows\System32\displayswitch.exe" /clone
    Start-Sleep -Seconds 3 
} elseif ($currentConfig.UseHDR) {
    [WinAPIKeyboard]::ToggleHDR()
    Start-Sleep -Seconds 6 
}

Set-Location $gameDir
$pInfo = New-Object System.Diagnostics.ProcessStartInfo
$pInfo.FileName = $exe
$pInfo.Arguments = $gameArgsString
$pInfo.WorkingDirectory = $gameDir
$pInfo.UseShellExecute = $false 
[System.Diagnostics.Process]::Start($pInfo) | Out-Null

# ------------------------------------------------------------------------------
# БЛОК 6: СИСТЕМНИЙ ТРЕЙ ТА ЗАВЕРШЕННЯ В ОДИН КЛІК
# ------------------------------------------------------------------------------
if ($currentConfig.Use2K -or $currentConfig.UseClone -or $currentConfig.UseHDR) {
    
    $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $notifyIcon.Text = "Натисніть, щоб завершити ігрову сесію"

    try {
        $notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exe)
    } catch {
        $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
    }

    $notifyIcon.Add_MouseUp({
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            
            $notifyIcon.Visible = $false
            $notifyIcon.Dispose()

            if ($currentConfig.UseClone) {
                & "C:\Windows\System32\displayswitch.exe" /internal
                Start-Sleep -Seconds 10 
            } elseif ($currentConfig.UseHDR) {
                [WinAPIKeyboard]::ToggleHDR()
                Start-Sleep -Seconds 10 
            }

            if ($currentConfig.Use2K -and (Test-Path $script5K)) {
                & $script5K
                Wait-DisplayResolution 5120
            }
            
            [System.Windows.Forms.Application]::Exit()
        }
    })

    $notifyIcon.Visible = $true
    [System.Windows.Forms.Application]::Run()
}
else {
    Start-Sleep -Seconds 10
    exit
}