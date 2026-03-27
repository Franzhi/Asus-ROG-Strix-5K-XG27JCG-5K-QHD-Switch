# ======================================================================
# БЛОК 1: РАННЯ ПЕРЕВІРКА СТАНУ (FAIL-FAST)
# Мета: Визначити поточну роздільну здатність. Якщо ми ВЖЕ у 5K, 
# скрипт завершує роботу БЕЗ запиту прав Адміністратора.
# ======================================================================
$is2K = $false
$videoControllers = Get-CimInstance Win32_VideoController
foreach ($vc in $videoControllers) {
    if ($vc.CurrentHorizontalResolution -eq 2560) {
        $is2K = $true
        break
    }
}

if (-not $is2K) {
    exit # Ми вже у 5K (або іншому режимі), негайний тихий вихід
}

# ======================================================================
# БЛОК 4: ІНІЦІАЛІЗАЦІЯ WINAPI (DDC/CI) ТА ПОШУК МОНІТОРА
# ======================================================================
$ClassCode = @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class MonitorManager {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct PHYSICAL_MONITOR {
        public IntPtr hPhysicalMonitor;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szPhysicalMonitorDescription;
    }

    delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, IntPtr lprcMonitor, IntPtr dwData);

    [DllImport("user32.dll")]
    static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumProc lpfnEnum, IntPtr dwData);

    [DllImport("dxva2.dll", SetLastError = true)]
    static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, out uint pdwNumberOfPhysicalMonitors);

    [DllImport("dxva2.dll", SetLastError = true)]
    static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint dwPhysicalMonitorArraySize, [Out] PHYSICAL_MONITOR[] pPhysicalMonitorArray);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool DestroyPhysicalMonitors(uint dwPhysicalMonitorArraySize, [Out] PHYSICAL_MONITOR[] pPhysicalMonitorArray);

    [DllImport("dxva2.dll", SetLastError = true)]
    public static extern bool SetVCPFeature(IntPtr hPhysicalMonitor, byte bVCPCode, uint dwNewValue);

    public static PHYSICAL_MONITOR[] GetAllMonitors() {
        var monitors = new List<PHYSICAL_MONITOR>();
        MonitorEnumProc callback = (IntPtr hMonitor, IntPtr hdcMonitor, IntPtr lprcMonitor, IntPtr dwData) => {
            uint count = 0;
            if (GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, out count) && count > 0) {
                PHYSICAL_MONITOR[] physMonitors = new PHYSICAL_MONITOR[count];
                if (GetPhysicalMonitorsFromHMONITOR(hMonitor, count, physMonitors)) {
                    monitors.AddRange(physMonitors);
                }
            }
            return true;
        };
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, callback, IntPtr.Zero);
        return monitors.ToArray();
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]"MonitorManager").Type) {
    Add-Type -TypeDefinition $ClassCode
}

$allMonitors = [MonitorManager]::GetAllMonitors()
$asusMonitor = $null

foreach ($monitor in $allMonitors) {
    if ($monitor.szPhysicalMonitorDescription -match "ROG|STRIX|XG27JCG") {
        $asusMonitor = $monitor
    }
}

if ($null -eq $asusMonitor) {
    $asusMonitor = $allMonitors[0]
}

$hPhys = $asusMonitor.hPhysicalMonitor

# ======================================================================
# БЛОК 5: ВІДПРАВКА АПАРАТНИХ КОМАНД (ПЕРЕМИКАННЯ НА 5K)
# ======================================================================
$vcpJoystick = 0xEB

function Send-VCPDirect($val, $ms) {
    [void][MonitorManager]::SetVCPFeature($hPhys, $vcpJoystick, $val)
    Start-Sleep -Milliseconds $ms
}

# Нова, апаратно правильна послідовність команд з безпечними таймінгами
Send-VCPDirect 1 1000  # Виклик OSD
Send-VCPDirect 4 250  # Праворуч
Send-VCPDirect 3 250  # Вниз
Send-VCPDirect 6 250  # Enter

[void][MonitorManager]::DestroyPhysicalMonitors($allMonitors.Length, $allMonitors)