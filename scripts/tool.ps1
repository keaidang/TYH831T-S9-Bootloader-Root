<#
  公共函数：路径、引号、spd_dump 调用、哈希
  其它脚本 dot-source 本文件。
#>
$ErrorActionPreference = 'Continue'

$script:PackRoot = Split-Path $PSScriptRoot -Parent
$script:Bin     = Join-Path $PackRoot 'bin'
$script:Dump    = Join-Path $PackRoot 'dump'
$script:Out     = Join-Path $PackRoot 'out'
$script:Logs    = Join-Path $PackRoot 'logs'
$script:Verify  = Join-Path $Dump 'verify'
$script:Exe     = Join-Path $Bin 'spd_dump.exe'

New-Item -ItemType Directory -Force -Path $Dump, $Out, $Logs, $Verify | Out-Null

function Quote-Arg([string]$a) {
    if ($a -match '[\s"]') { return '"' + ($a -replace '"', '\"') + '"' }
    return $a
}

function Invoke-Spd {
    param(
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][string[]]$Commands,
        [string]$WorkDir = $Bin,
        [int]$Wait = 900
    )
    if (-not (Test-Path $Exe)) { throw "找不到 spd_dump.exe：$Exe" }

    $argv = @('--wait', "$Wait", 'baudrate', '115200',
              'exec_addr', '0x65012f48',
              'fdl', 'fdl1-dl.bin', '0x65000800',
              'fdl', 'fdl2-dl.bin', '0xb4fffe00', 'exec') + $Commands

    $line = (@($Exe) + $argv | ForEach-Object { Quote-Arg $_ }) -join ' '
    $log = Join-Path $Logs ("{0}_{1}.log" -f $Tag, (Get-Date -Format 'yyyyMMdd_HHmmss'))

    Push-Location $WorkDir
    try {
        cmd /d /c ($line + ' 2>&1 <nul') | Tee-Object -FilePath $log
    }
    finally { Pop-Location }

    return $log
}

function Get-Sha([string]$path) {
    if (-not (Test-Path $path)) { return '' }
    return (Get-FileHash $path -Algorithm SHA256).Hash
}

function Show-Header([string]$title) {
    Write-Host ''
    Write-Host '==========================================================' -ForegroundColor Cyan
    Write-Host ("  {0}" -f $title) -ForegroundColor Cyan
    Write-Host '==========================================================' -ForegroundColor Cyan
}

function Wait-Enter { Write-Host ''; Read-Host '按回车继续' | Out-Null }
