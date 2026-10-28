<#
  驱动安装指引 + 打开设备管理器
  本包自带 UNISOC sprdvcom 驱动（driver\ 目录）
#>
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'tool.ps1')

Show-Header '安装 UNISOC 驱动'

$drv = Join-Path $PackRoot 'driver\sprdvcom.inf'
if (-not (Test-Path $drv)) { Write-Host '  [X] driver\sprdvcom.inf 缺失' -ForegroundColor Red; Wait-Enter; exit 1 }

Write-Host '  Windows 10/11 首次插上手机时通常会自动装好。'
Write-Host '  如果「2-连接诊断.bat」显示驱动没起来（黄色感叹号 / 错误码 10、28、31），按下面做：'
Write-Host ''
Write-Host '  ① 手机进入下载模式：关机 -> 按住音量下 -> 插线 -> 7~10 秒'
Write-Host '  ② 打开设备管理器（本脚本会帮你打开）'
Write-Host '  ③ 在「端口 (COM 和 LPT)」或「其他设备」里找到 SPRD U2S Diag'
Write-Host '  ④ 右键 -> 更新驱动程序 -> 浏览我的电脑 -> 指向本包 driver 目录'
Write-Host ('     ' + (Join-Path $PackRoot 'driver'))
Write-Host '  ⑤ 装完再跑一次「2-连接诊断.bat」确认显示驱动正常'
Write-Host ''
Write-Host '  如果设备带黄色感叹号且装不上：右键 -> 卸载设备 -> 勾“删除驱动程序”-> 拔插重来'
Write-Host ''

Start-Process devmgmt.msc
Write-Host ('  驱动目录：{0}' -f (Join-Path $PackRoot 'driver'))
Write-Host ''
Write-Host '  （设备管理器已打开）' -ForegroundColor Cyan
Wait-Enter
