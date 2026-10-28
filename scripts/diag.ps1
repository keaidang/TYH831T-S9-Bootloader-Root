<#
  连接诊断：设备在不在、驱动对不对、该不该装驱动
#>
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'tool.ps1')

Show-Header '连接诊断'

$devs = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
          Where-Object { $_.InstanceId -match 'VID_1782' })

if ($devs.Count -eq 0) {
    Write-Host '  当前没有检测到下载模式设备（1782:4D00）' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  进入方法：' -ForegroundColor Yellow
    Write-Host '    1) 手机完全关机'
    Write-Host '    2) 按住【音量下】不松手'
    Write-Host '    3) 插上数据线，保持 7~10 秒'
    Write-Host '    4) 松手（屏幕全黑是正常的）'
    Write-Host ''
    Write-Host '  注意：没有工具握手时，这个模式只能撑 30~60 秒就会自动退出。' -ForegroundColor Yellow
}
else {
    foreach ($d in $devs) {
        $svc = ''
        try { $svc = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_Service' -ErrorAction Stop).Data } catch { }
        $inf = ''
        try { $inf = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction Stop).Data } catch { }
        $prob = 0
        try { [void][int]::TryParse("$((Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction Stop).Data)", [ref]$prob) } catch { }

        Write-Host ("  设备  : {0}" -f $d.FriendlyName)
        Write-Host ("  状态  : {0}" -f $d.Status)
        Write-Host ("  驱动  : {0}  ({1})" -f $svc, $inf)

        if ($prob -ne 0 -or $d.Status -ne 'OK') {
            Write-Host ("  [!] 驱动没起来（错误码 {0}）→ 用「1-安装驱动.bat」重装驱动" -f $prob) -ForegroundColor Red
        }
        elseif ($svc -match 'sprdvcom') {
            Write-Host '  [OK] 驱动正常，可以继续' -ForegroundColor Green
        }
        else {
            Write-Host ("  [!] 驱动不是 sprdvcom（是 {0}）→ 需要安装本包里的驱动" -f $svc) -ForegroundColor Red
        }
    }
}

Write-Host ''
Write-Host '--- 串口列表 ---'
Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
    Where-Object { $_.ClassGuid -eq '{4d36e978-e325-11ce-bfc1-08002be10318}' } |
    Select-Object Name | Format-Table -AutoSize | Out-String -Width 200 | Write-Host

Wait-Enter
