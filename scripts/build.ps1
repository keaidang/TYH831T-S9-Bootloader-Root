<#
  用 dump 里的原厂 uboot_b.bin 生成 magic64 解锁镜像
  产物：out\uboot_b_magic64.img
  流程：Python 读原厂镜像 -> 校验哈希/原指令 -> 打包（签名保持不变）-> 校验
#>
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'tool.ps1')

Show-Header '生成解锁镜像（magic64）'

$src = Join-Path $Dump 'uboot_b.bin'
if (-not (Test-Path $src)) { Write-Host ('  [X] 缺少 {0}，先跑「3-备份分区.bat」' -f $src) -ForegroundColor Red; Wait-Enter; exit 1 }

$py = Get-PythonPath
if (-not $py) { Write-Host '  [X] 找不到 Python 3（安装时请勾选 Add to PATH）' -ForegroundColor Red; Wait-Enter; exit 1 }

$builder = Join-Path $PackRoot 'magic64\build_unlock_image.py'
$outImg = Join-Path $Out 'uboot_b_magic64.img'

& $py.Exe @($py.Args) $builder --input $src --output $outImg
$code = $LASTEXITCODE
Write-Host ''
if ($code -ne 0) {
    Write-Host '  [X] 生成失败。常见原因：' -ForegroundColor Red
    Write-Host '      - 你的固件版本与本教程不同（原厂 uboot_b 哈希不是 F0BA7AEC…）'
    Write-Host '      - 需要按文档「固件不同怎么办」重新定位补丁点'
    Wait-Enter; exit 1
}
Write-Host ('  [OK] 已生成：{0}' -f $outImg) -ForegroundColor Green
Write-Host ('  SHA256: {0}' -f (Get-Sha $outImg))
Write-Host ''
Write-Host '  下一步：跑「6-刷入解锁镜像.bat」' -ForegroundColor Cyan
Wait-Enter
