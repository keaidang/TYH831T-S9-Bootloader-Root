# 第三方组件与再分发说明

本仓库**只包含**自己写的脚本与文档。

以下内容**不在仓库里**，需要你自行获取；完整离线包（Releases 附件）里会打包一部分，但这属于便利分发，不代表授权：

| 组件 | 来源 | 许可 / 说明 |
|---|---|---|
| `spd_dump.exe`、`Channel9.dll`、`Channel.ini` | [TomKing062/CVE-2022-38694_unlock_bootloader](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader) | 上游项目分发；`Channel9.dll` 为 UNISOC 组件，版权归原厂 |
| `fdl1-dl.bin`、`fdl2-dl.bin`、`custom_exec_no_verify_65012f48.bin` | 同上（UMS9620 universal 包） | 上游项目分发 |
| `magic_pack_ums9620.py` | [TheGammaSqueeze/UnisocBypass](https://github.com/TheGammaSqueeze/UnisocBypass) `tools/` | 上游未标注明确许可，本仓库按“保留署名 + 原样引用”使用，见文件头注释 |
| UNISOC SPRD USB 驱动（`sprdvcom.inf/.cat/.sys`） | 设备厂商 / UNISOC | **专有驱动**，版权归原厂；不建议在公开仓库再分发 |
| Magisk | [topjohnwu/Magisk](https://github.com/topjohnwu/Magisk) | GPL-3.0；建议在文档里给链接而不是打包 APK |
| 设备固件（`uboot_b.bin`、`boot_b.bin` 等） | 你自己的设备 | **不要上传**：既是版权固件，也包含你设备的唯一数据 |

## 建议

- 公开仓库里**不放**驱动、Magisk APK、任何分区镜像
- 如果要发“一键包”，走 GitHub Releases，并在 Release 说明里注明各组件的来源与许可
- 使用者应自行核对 `SHA256SUMS.txt`

## 免责

本仓库作者不对任何设备损坏、数据丢失、保修失效或法律后果负责。
相关内容仅针对作者自用设备的一次实验记录。
