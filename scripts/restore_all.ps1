<#
  刷回已备份的分区（完整恢复）
  ------------------------------------------------------------
  把 dump\ 里所有备份过的分区原样写回设备，用于：
    - 解锁后想彻底回到原厂状态
    - 系统被改坏、需要整体恢复
  只写 dump\ 里确实存在的分区，不写 userdata（当初就没备份）。

  用法：
    powershell -ExecutionPolicy Bypass -File .\bl_restore_all.ps1
    powershell -ExecutionPolicy Bypass -File .\bl_restore_all.ps1 -Only splloader,uboot_b,boot_b
    powershell -ExecutionPolicy Bypass -File .\bl_restore_all.ps1 -SkipVerify
#>
[CmdletBinding()]
param(
    [ValidateSet('libusb', 'sprd')][string]$Mode = 'sprd',
    [int]$Baud = 115200,
    [string]$DumpDir = '',
    [int]$Wait = 900,
    [string[]]$Only = @(),
    [switch]$SkipVerify,
    [switch]$Yes
)

. (Join-Path $PSScriptRoot 'tool.ps1')

if ($DumpDir) { $Dump = $DumpDir; $Verify = Join-Path $Dump 'verify' }

Show-Header '刷回已备份的分区（完整恢复）'

# ---- 收集要写的分区 ----
$skip = @('pgpt')
$files = @()
if ($Only.Count -gt 0) {
    foreach ($n in $Only) {
        $f = Join-Path $Dump ($n + '.bin')
        if (Test-Path $f) { $files += Get-Item $f } else { Write-Host ("  [!] 跳过（没有备份）：{0}" -f $n) -ForegroundColor Yellow }
    }
}
else {
    $files = @(Get-ChildItem $Dump -Filter *.bin -File |
               Where-Object { $_.BaseName -notin $skip -and $_.BaseName -notlike 'super.chunk*' -and $_.Name -notlike '*_after*' })
}

if ($files.Count -eq 0) {
    Write-Host '  [X] dump 目录里没有可写回的分区，先跑「3-备份分区.bat」' -ForegroundColor Red
    Wait-Enter; exit 1
}
if ($files.Count -lt 50 -and $Only.Count -eq 0) {
    Write-Host ("  [!] 只找到 {0} 个分区，备份像是残缺的（正常应有 70+）。" -f $files.Count) -ForegroundColor Red
    Write-Host '      继续写回可能让设备处于"一半新一半旧"的状态。' -ForegroundColor Red
    if (-not $Yes) {
        $a = Read-Host '  仍要继续？输入 yes'
        if ($a -ne 'yes') { exit 1 }
    }
}

# 顺序：小分区在前，super 最后（万一中途失败，关键分区已经回位）
$ordered = @($files | Where-Object { $_.BaseName -ne 'super' } | Sort-Object Length) + @($files | Where-Object { $_.BaseName -eq 'super' })
$totalBytes = ($ordered | Measure-Object Length -Sum).Sum

Write-Host ''
Write-Host ("  将写回 {0} 个分区，共 {1:N2} GB" -f $ordered.Count, ($totalBytes / 1GB)) -ForegroundColor Cyan
Write-Host '  包含：' -ForegroundColor DarkGray
$ordered | Group-Object { if ($_.Length -gt 1GB) { '大分区' } elseif ($_.Length -gt 16MB) { '中等' } else { '小分区' } } |
    ForEach-Object { Write-Host ("    {0}: {1} 个" -f $_.Name, $_.Count) -ForegroundColor DarkGray }
Write-Host ''

if (-not $Yes) {
    Write-Host '  这会覆盖设备上对应分区的全部内容（splloader / uboot / boot / super ...）。' -ForegroundColor Yellow
    $a = Read-Host '  确认继续？输入 yes'
    if ($a -ne 'yes') { Write-Host '  已取消'; Wait-Enter; exit 0 }
}

# ---- 组装命令 ----
$cmds = @()
foreach ($f in $ordered) { $cmds += @('w', $f.BaseName, $f.FullName) }

$verifyNames = @('splloader', 'uboot_a', 'uboot_b', 'boot_a', 'boot_b', 'vbmeta_a', 'vbmeta_b', 'miscdata', 'misc')
$verifyPlan = @()
if (-not $SkipVerify) {
    $cmds += @('path', $Verify)
    foreach ($n in $verifyNames) {
        $src = Join-Path $Dump ($n + '.bin')
        if (-not (Test-Path $src)) { continue }
        $len = (Get-Item $src).Length
        $cmds += @('read_part', $n, '0', ('0x{0:X}' -f $len), ($n + '_after.bin'))
        $verifyPlan += [pscustomobject]@{ 分区 = $n; 源 = $src; 校验 = (Join-Path $Verify ($n + '_after.bin')) }
    }
}
$cmds += 'reset'

Write-Host '  现在进下载模式：关机 -> 按住音量下 -> 插线 -> 7~10 秒' -ForegroundColor Yellow
Write-Host '  写入期间不要拔线，super 那个大分区会跑一会儿。' -ForegroundColor Yellow
Write-Host ''

$log = Invoke-Spd -Tag 'restore' -Commands $cmds -Wait $Wait

if ($env:SPD_DRYRUN -eq '1') { Wait-Enter; return }

Write-Host ''
Write-Host '  --- 回读校验 ---'
$fail = 0
foreach ($p in $verifyPlan) {
    if (-not (Test-Path $p.校验)) { Write-Host ("  [缺失] {0}" -f $p.分区) -ForegroundColor Red; $fail++; continue }
    $a = Get-Sha $p.源; $b = Get-Sha $p.校验
    if ($a -eq $b) { Write-Host ("  [一致] {0}" -f $p.分区) -ForegroundColor Green }
    else { Write-Host ("  [不一致] {0}" -f $p.分区) -ForegroundColor Red; $fail++ }
}
Write-Host ''
if ($fail -eq 0) {
    Write-Host '  [OK] 关键分区已回位，设备应回到备份时的状态。' -ForegroundColor Green
}
else {
    Write-Host ("  [!] {0} 个分区不一致，重跑一次；仍不一致请检查数据线/端口" -f $fail) -ForegroundColor Red
}
Write-Host ("  日志：{0}" -f $log)
Wait-Enter
