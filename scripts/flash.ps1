<#
  写分区 / 回滚
  ------------------------------------------------------------
  只写指定分区，写完立刻读回比对 SHA256。
  用法（一般由 bat 调用）：
    -Partition uboot_b -Image ..\out\uboot_b_magic64.img
    -Partition boot_b  -Image C:\path\magisk_patched.img
    -Partition uboot_b -Rollback
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('uboot_b', 'boot_b', 'init_boot_b', 'misc')][string]$Partition,
    [string]$Image = '',
    [switch]$Rollback,
    [int]$Wait = 900
)

. (Join-Path $PSScriptRoot 'tool.ps1')

$maxSize = @{ uboot_b = 0x300000; boot_b = 0x4000000; init_boot_b = 0x800000; misc = 0x100000 }[$Partition]
$stock = Join-Path $Dump ($Partition + '.bin')

if ($Rollback) {
    if (-not (Test-Path $stock)) { Write-Host ("  [X] 找不到原厂备份 {0}" -f $stock) -ForegroundColor Red; Wait-Enter; exit 1 }
    $img = $stock
    $title = "回滚 $Partition（写回原厂）"
}
else {
    if (-not $Image) { Write-Host '  [X] 没有指定镜像 -Image' -ForegroundColor Red; Wait-Enter; exit 1 }
    $img = $Image
    $title = "写入 $Partition"
    if (-not (Test-Path $stock)) {
        Write-Host '  [!] 警告：dump 里没有原厂备份，出问题将无法回滚' -ForegroundColor Red
        $ans = Read-Host '  仍要继续？输入 yes'
        if ($ans -ne 'yes') { exit 1 }
    }
}

if (-not (Test-Path $img)) { Write-Host ("  [X] 找不到镜像 {0}" -f $img) -ForegroundColor Red; Wait-Enter; exit 1 }
$len = (Get-Item $img).Length
if ($len -gt $maxSize) { Write-Host ("  [X] 镜像 {0:N0} 字节 > 分区上限 {1:N0}" -f $len, $maxSize) -ForegroundColor Red; Wait-Enter; exit 1 }

# 头校验（boot/uboot 都适用）
$fs = [IO.File]::OpenRead($img); $head = New-Object byte[] 8; [void]$fs.Read($head, 0, 8); $fs.Dispose()
$magic = [Text.Encoding]::ASCII.GetString($head)
$expect = @{ uboot_b = 'DHTB'; boot_b = 'ANDROID!'; init_boot_b = 'ANDROID!'; misc = '' }[$Partition]
if ($expect -and $magic -notlike "$expect*") {
    Write-Host ("  [X] 头不对：期望 {0}，实际 {1}" -f $expect, $magic) -ForegroundColor Red
    Wait-Enter; exit 1
}

$hash = Get-Sha $img
$rbName = $Partition + '_after.bin'
$rb = Join-Path $Verify $rbName

Show-Header $title
Write-Host ("  分区  : {0}（上限 {1:N0}）" -f $Partition, $maxSize)
Write-Host ("  镜像  : {0}" -f $img)
Write-Host ("  大小  : {0:N0} 字节" -f $len)
Write-Host ("  SHA256: {0}" -f $hash)
Write-Host ''
Write-Host '  现在进下载模式：关机 -> 按住音量下 -> 插线 -> 7~10 秒' -ForegroundColor Yellow
Write-Host ''

$log = Invoke-Spd -Tag ("flash_" + $Partition) -Commands @(
    'path', $Verify,
    'w', $Partition, $img,
    'read_part', $Partition, '0', ('0x{0:X}' -f $len), $rbName,
    'reset'
) -Wait $Wait
if ($env:SPD_DRYRUN -eq '1') { Wait-Enter; exit 0 }

Write-Host ''
Write-Host '  --- 读回校验 ---'
if (-not (Test-Path $rb)) {
    Write-Host '  [X] 没有读回文件，写入可能失败。不要重启，重跑本脚本或回滚。' -ForegroundColor Red
    Write-Host ("  日志：{0}" -f $log)
    Wait-Enter; exit 1
}
$rbLen = (Get-Item $rb).Length
$rbHash = Get-Sha $rb
Write-Host ("  读回大小: {0:N0}" -f $rbLen)
Write-Host ("  读回 SHA: {0}" -f $rbHash)
if ($rbLen -eq $len -and $rbHash -eq $hash) {
    Write-Host '  [OK] 读回与写入镜像完全一致' -ForegroundColor Green
}
else {
    Write-Host '  [!] 不一致：重写一次；仍不一致请回滚' -ForegroundColor Red
}
Write-Host ("  日志：{0}" -f $log)
Wait-Enter
