# TYH831T（天翼铂顿 S9）Bootloader 解锁 + Root

> 紫光展锐 UMS9620 · Android 13 · A/B 双槽 · **AP 侧解锁，不触碰 TEE / eFuse**
>
> 用 CVE-2022-38694 进入下载模式，用 **magic64（签名保持）** 改写 `uboot_b` 的运行期行为，
> 再用 Magisk 给 `boot_b` 打补丁拿到 root。

---

## ⚠️ 免责声明

> 以下内容仅针对本人自用的设备，不对任何人的设备做任何相关保障。
>
> 使用前请自行校验相关脚本和操作安全性。
>
> 另外请注意：**解锁一定会清空数据，请注意备份**。
>
> 遇到报错或者有问题，第一步去问 AI，让 AI 给出解决的方式，最好是用本地的 agent 直接去解决。
>
> 本教程和解锁所需的脚本以及漏洞利用链都是由 AI 进行复现和编辑的。

补充说明：

- 本仓库**不包含**任何厂商固件、签名材料、UNISOC 驱动或 Magisk 安装包，请自行从官方/上游渠道获取
- 解锁后 `verifiedbootstate=orange`，保修作废，银行/支付类 App 可能拒绝运行
- **这是 AP 侧解锁**：只改启动链里的判定，安全世界（TEE）状态不变

---

## 这个仓库是什么

一台 **TYH831T（天翼铂顿 S9，SoC UMS9620，平台 `ums9620_2h10`，Android 13，活动槽 `_b`）**
从零到 root 的完整过程记录 + 可复现脚本。

验证过的固件：

```
vargo/ums9620_2h10_native/ums9620_2h10:13/TP1A.220624.014/root01261833:user/release-keys
原厂 uboot_b.bin SHA256 = F0BA7AEC4D4FF8A9F51B8218A18253851A5ADC1FA12397703D4B03A221AE877F
```

仓库提供：

| 内容 | 说明 |
|---|---|
| 全流程脚本 | 备份 / 校验 / 生成镜像 / 刷写 / 回滚，PowerShell + bat 启动器 |
| magic64 打包器 | 纯 Python，无第三方依赖，**输出确定性可复现** |
| 逆向分析记录 | `uboot_b` 里 `get_lock_status()` 的定位过程与实证数据 |
| 完整教程 | [`教程.md`](教程.md) |

**不提供**（也不应该由本仓库分发）：原厂分区镜像、UNISOC 驱动、Magisk APK、`spd_dump` 等第三方工具。
完整离线包（含上述第三方文件）见 Releases。

---

## 利用链

### 第一段：进入下载模式（CVE-2022-38694）

```
BROM（掩膜 ROM，不可写）
  │  校验加载时存在绕过点 → 可把 shellcode 放到指定地址执行
  │  exec_addr 0x65012f48 + custom_exec_no_verify_65012f48.bin(96B)
  ▼
FDL1（0x65000800，初始化 DRAM）
  ▼
FDL2（0xb4fffe00，提供分区表与读写）
```

### 第二段：让 SPL 接受改过的 uboot（magic64）

SPL 会对 `uboot` 做 **RSA 校验**，所以"改字节再重算哈希"必死。

magic64 的做法是**一个字节都不动签名覆盖区**：

```
0x000  DHTB 头            mImgSize += 0x100
0x200  跳转指令            B -> shellcode
0x210  原厂 signed payload ← 逐字节不变，RSA 依然有效
...    shellcode(0x70) + 补丁表
...    SIMGHDR 页脚        payload_offset 0x200 -> 0x210
...    RSA 证书            整体后移 0x100
```

开机时：SPL 校验通过 → 跳到 `0x200` → shellcode 把 payload 搬回 `0xB5000000`、按补丁表改字 → 跳回 `_start`。

### 第三段：改的那一个字

`get_lock_status()`（`0xB506080C`）读取 `miscdata` 偏移 `0x2000` 的 `0x1dc` 字节锁记录并校验：

```
0xB506085C  cbnz w0, 0xB5060888   ; 校验失败 -> 走"锁定"分支
0xB5060864  mov  w0, #1           ; 成功 -> 写 1（已解锁）
0xB506086C  str  w0, [x1, #0x8c8] ;   g_DeviceStatus = 1
```

把 `0xB506085C` 的 `0x35000160` 换成 `0xD503201F`（`nop`）→ 永远走解锁分支。

`g_DeviceStatus`（`0xB51138C8`）是唯一的锁状态缓存，AVB、`flash.locked`、`verifiedbootstate`、`vbmeta.device_state` 这些 AP 侧读者全部跟着变。

> `LOAD_BASE = 0xB5000000` 是从**本机自己的 `uboot_log` 分区**实证的，不是照抄：
> `load_buf is 0x0xb4fffe00` + `sechdr_offset is 0x10a0a0`，与镜像页脚偏移完全吻合。

### 第四段：root（与解锁无关）

本机 `init_boot_b` 是**全零空分区**，ramdisk 实际在 `boot_b`（kernel 37 MB + ramdisk 1.4 MB，header v4 / lz4）。

所以 Magisk 打的是 **`boot_b`**，不是 `init_boot_b`（后者会报 `Unable to unpack boot image`）。

---

## 快速开始

### 方式 A：用完整离线包（推荐给普通用户）

1. 到 [Releases](../../releases) 下载 `TYH831T-Unlock-Root-Pack-vX.Y.zip`
2. 解压，按编号双击 `1-…8-` 的 bat
3. 详细判据看 [`教程.md`](教程.md)

### 方式 B：只用本仓库脚本

需要自备 `bin/` 目录，放入上游工具（见下）。目录结构：

```
TYH831T-Bootloader-Unlock\
├── 1-安装驱动.bat … 8-回滚.bat
├── scripts\      PowerShell 实现
├── magic64\      打包器
├── bin\          ← 你自己放：spd_dump.exe / Channel9.dll / Channel.ini /
│                         fdl1-dl.bin / fdl2-dl.bin / custom_exec_no_verify_65012f48.bin
├── driver\       ← 你自己放：UNISOC sprdvcom 驱动（可选，Windows 常能自动装）
├── dump\         备份产物（自动创建）
├── out\          生成的镜像
└── logs\         会话日志
```

上游工具来源：

- `spd_dump.exe` / `Channel9.dll` / `Channel.ini` / `fdl1-dl.bin` / `fdl2-dl.bin` / `custom_exec_no_verify_65012f48.bin`
  → [TomKing062/CVE-2022-38694_unlock_bootloader Releases](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/releases)（选 UMS9620 universal 包）
- Magisk → [topjohnwu/Magisk Releases](https://github.com/topjohnwu/Magisk/releases)
- Python 3（生成解锁镜像用）

---

## 八步流程

| 步骤 | 脚本 | 判据 |
|---|---|---|
| 0 | 装驱动 + 进下载模式 | 设备管理器出现 `SPRD U2S Diag (COMx)`，无感叹号 |
| 1 | `2-连接诊断.bat` | `驱动 : sprdvcom` + `[OK]` |
| 2 | `3-备份分区.bat` | 71 个分区、约 6.7 GB、生成 `备份清单.csv` |
| 3 | `4-校验备份.bat` | 大部分 `[一致]`（`miscdata`/`metadata` 例外见下） |
| 4 | `5-生成解锁镜像.bat` | 输出 `9E1CF21E…34350F5C` |
| 5 | `6-刷入解锁镜像.bat` | `[OK] 读回与写入镜像完全一致` |
| 6 | 首次开机 → recovery 清数据 | `flash.locked=0` / `orange` / `unlocked` |
| 7 | Magisk 打 `boot_b` → `7-刷入root镜像.bat` | `su -c id` → `uid=0(root)` |

每步之间都要**彻底断电重进下载模式**：

> 手机关机 → 按住【音量下】不松手 → 插数据线 → 保持 7~10 秒 → 松手（屏幕全黑正常）

---

## 关键数据（供核对）

| 项目 | 值 |
|---|---|
| 分区总数 | 73（`r all` 实际读 71 个，跳过 userdata/cache/blackbox） |
| 存储 | UFS，活动槽 `_b` |
| `splloader` | 262,144 B · `8F3C0DBE…8FC61` |
| `uboot_b` 原厂 | 3,145,728 B · `F0BA7AEC…AE877F` |
| `uboot_b` 解锁 | 3,145,728 B · `9E1CF21E…34350F5C` |
| `boot_b` 原厂 | 67,108,864 B · `FA02B1E7…687383C` |
| `boot_b` root | 67,108,864 B · `127FA3AF…D2664776` |
| `init_boot_b` | 8,388,608 B · **全零（未启用）** |
| `persist` | 2,097,152 B · `FC947549…BC71D28` |

补丁点：

```
code offset 0x6085C   file 0x60A5C   va 0xB506085C
原指令 0x35000160  ->  0xD503201F
LOAD_BASE 0xB5000000
```

---

## 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| `Waiting for dl_diag connection` 一直等 | 驱动没起来 / 设备已退出下载模式 | 跑 `2-连接诊断.bat`；重装驱动；重进模式 |
| `usb_send failed (0/1)` | 手机卡在 FDL1/FDL2，BROM 不响应 | **长按电源 20 秒彻底断电**，按键组合救不回来 |
| `unexpected response (0x008b)` + `timeout` | 921600 波特率误码 | 脚本全程 115200，正常不会出现 |
| 写入后读回不一致 | 传输抖动 | 重写一次；仍不一致 → 回滚 |
| Magisk `Unable to unpack boot image` | 选错 `init_boot_b.img`（8 MB 全零） | 改选 64 MB 的 `boot_b` |
| 指纹录入报"传感器脏" | 指纹 TA 会话状态卡死，不是硬件 | 重启 → 删除所有指纹重录 → 清 `/data/vendor/fingerprint` → 最后才恢复出厂 |
| 开机停在 recovery | 锁状态变更导致 FBE 不匹配 | 正常，选 Wipe data |

`miscdata` / `metadata` 在校验时显示"不一样"是**正常的**：这两个分区在 Android 运行期会被系统改写，两次读取之间只要开过机就会变。它们不参与解锁写入。

---

## 固件不同怎么办

本仓库的补丁点针对 `F0BA7AEC…AE877F` 这一版 `uboot_b`。**固件不同脚本会直接拒绝**（`build_unlock_image.py` 会校验整文件哈希与原指令）。

重新定位的方法见 [`docs/逆向分析.md`](docs/逆向分析.md)：

1. 用 capstone 反汇编 payload（基址 `0xB5000000`）
2. 找 `mov x0, #0x1dc` → 读 `miscdata 0x2000` → `bl <校验>` → `cbnz w0, <锁定分支>` 的函数
3. 确认成功分支里有 `mov w0, #1` + `str w0, [x?, #0x8c8]`
4. 把那个 `cbnz` 的偏移传给 `--offset`

---

## 已知限制

- **只测过一台**，且只测过一个固件版本
- 解锁后 OTA 会覆盖 `uboot_b`，解锁与 root 一起消失
- 银行 / DRM / 支付类 App 大概率拒绝运行
- `verifiedbootstate=orange` 属于正常解锁态，不是故障

---

## 致谢

| 项目 | 说明 |
|---|---|
| [TomKing062/CVE-2022-38694_unlock_bootloader](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader) | BROM 漏洞工具链（`spd_dump`、`fdl1/fdl2`、跳板） |
| [Issue #337](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/issues/337) | 同平台 UMS9620 的 SPL 解锁完整报告（ZTE W202DS） |
| [TheGammaSqueeze/UnisocBypass](https://github.com/TheGammaSqueeze/UnisocBypass) | `magic_pack_ums9620.py` 的原始实现 |
| [zjh812/VN300E-UMS9620-root](https://github.com/zjh812/VN300E-UMS9620-root) | 同 SoC magic64 实战与方法论 |
| [topjohnwu/Magisk](https://github.com/topjohnwu/Magisk) | root |
| [NCC Group](https://research.nccgroup.com/2022/09/02/theres-another-hole-in-your-soc-unisoc-rom-vulnerabilities/) | 漏洞背景 |

---

## License

[MIT](LICENSE)（仅覆盖本仓库的脚本与文档；第三方工具与固件遵循其各自许可）
