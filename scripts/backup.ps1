<#
  全分区备份（只读）：除 userdata / cache / blackbox 外全部读出来
  产物：dump\*.bin + dump\pgpt.bin + dump\partition*.xml + dump\备份清单.csv
#>
[CmdletBinding()]
param([int]$Wait = 900)

. (Join-Path $PSScriptRoot 'tool.ps1')

Show-Header '全分区备份（只读，不改任何分区）'
Write-Host ('  输出目录：{0}' -f $Dump)
$free = (Get-PSDrive ([IO.Path]::GetPathRoot($Dump).TrimEnd(':\'))).Free
Write-Host ('  剩余空间：{0:N1} GB（约需 10 GB）' -f ($free / 1GB))
if ($free -lt 11GB) { Write-Host '  [X] 空间不足，先清理' -ForegroundColor Red; Wait-Enter; exit 1 }

Write-Host ''
Write-Host '  现在进下载模式：关机 -> 按住音量下 -> 插线 -> 保持 7~10 秒' -ForegroundColor Yellow
Write-Host ''

$log = Invoke-Spd -Tag 'backup' -Commands @('path', $Dump, 'r', 'all', 'reset') -Wait $Wait

# 收存工具目录里的 GPT / 分区表
foreach ($pat in 'pgpt.bin', 'partition_*.xml') {
    Get-ChildItem (Join-Path $Bin $pat) -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $Dump $_.Name) -Force
    }
}

$bins = Get-ChildItem $Dump -Filter *.bin -File
Write-Host ''
Write-Host ('  已落盘 {0} 个分区，共 {1:N2} GB' -f $bins.Count, (($bins | Measure-Object Length -Sum).Sum / 1GB))

$csv = foreach ($f in $bins) {
    [pscustomobject]@{ 分区 = $f.BaseName; 字节 = $f.Length; sha256 = (Get-FileHash $f.FullName -Algorithm SHA256).Hash }
}
$csv | Export-Csv (Join-Path $Dump '备份清单.csv') -NoTypeInformation -Encoding UTF8
Write-Host ('  [OK] 清单：{0}' -f (Join-Path $Dump '备份清单.csv')) -ForegroundColor Green
Write-Host ('  日志：{0}' -f $log)
Write-Host ''
Write-Host '  下一步：跑「3-校验备份.bat」，把关键分区再读一遍比对。' -ForegroundColor Cyan
Wait-Enter
