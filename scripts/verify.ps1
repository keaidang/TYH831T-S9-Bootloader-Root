<#
  二次重读校验：关键分区再读一遍，和 dump 里的比 SHA256
  注意：miscdata / metadata 在 Android 运行期会被系统改写，
        两次读取之间只要开过机就会不一样 —— 这是正常的，不是坏读。
#>
[CmdletBinding()]
param([int]$Wait = 900)

. (Join-Path $PSScriptRoot 'tool.ps1')

Show-Header '二次重读校验'

$key = @('splloader', 'uboot_a', 'uboot_b', 'miscdata', 'misc', 'boot_b', 'vbmeta_b', 'metadata', 'persist')
$cmds = @()
$plan = @()

foreach ($name in $key) {
    $src = Join-Path $Dump ($name + '.bin')
    if (-not (Test-Path $src)) { continue }
    $len = (Get-Item $src).Length
    $bn = $name + '.bin'
    $cmds += @('read_part', $name, '0', ('0x{0:X}' -f $len), $bn)
    $plan += [pscustomobject]@{ 分区 = $name; 源 = $src; 校验 = (Join-Path $Verify $bn) }
}

$super = Join-Path $Dump 'super.bin'
if (Test-Path $super) {
    $cmds += @('read_part', 'super', '0', '0x1000000', 'super.head.bin')
    $plan += [pscustomobject]@{ 分区 = 'super'; 源 = $super; 校验 = (Join-Path $Verify 'super.head.bin') }
}

if ($plan.Count -eq 0) { Write-Host '  [X] dump 目录里没有可校验的文件' -ForegroundColor Red; Wait-Enter; exit 1 }

Write-Host ('  将重读 {0} 项' -f $plan.Count)
Write-Host '  现在进下载模式：关机 -> 按住音量下 -> 插线 -> 7~10 秒' -ForegroundColor Yellow

$log = Invoke-Spd -Tag 'verify' -Commands (@('path', $Verify) + $cmds + 'reset') -Wait $Wait
if ($env:SPD_DRYRUN -eq '1') { Wait-Enter; return }

Write-Host ''
Write-Host '  --- 结果 ---'
$fail = 0
foreach ($p in $plan) {
    if (-not (Test-Path $p.校验)) { Write-Host ("  [缺失] {0}" -f $p.分区) -ForegroundColor Red; $fail++; continue }
    if ($p.分区 -eq 'super') {
        $fs = [IO.File]::OpenRead($p.源); $buf = New-Object byte[] (16MB); $n = $fs.Read($buf, 0, 16MB); $fs.Dispose()
        $h1 = ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($buf, 0, $n)) -replace '-', '')
    }
    else { $h1 = Get-Sha $p.源 }
    $h2 = Get-Sha $p.校验
    if ($h1 -eq $h2) { Write-Host ("  [一致] {0}" -f $p.分区) -ForegroundColor Green }
    else { Write-Host ("  [不一样] {0}  ← miscdata/metadata 若开过机属正常" -f $p.分区) -ForegroundColor Yellow; $fail++ }
}
Write-Host ''
if ($fail -eq 0) { Write-Host '  [OK] 全部一致，备份可用' -ForegroundColor Green }
else { Write-Host ('  [!] {0} 项不一致；若只是 miscdata/metadata，可忽略' -f $fail) -ForegroundColor Yellow }
Write-Host ('  日志：{0}' -f $log)
Wait-Enter
