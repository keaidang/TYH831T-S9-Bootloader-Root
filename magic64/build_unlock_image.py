#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从你自己的原厂 uboot_b.bin 生成 magic64 解锁镜像（签名保持不变）
================================================================

原理：
  SPL 会 RSA 校验 uboot 的 payload；直接改字节再重算哈希会被拒。
  magic64 的做法是：payload 一个字节都不动（签名继续有效），
  在 DHTB 头部后面插一段跳转 + shellcode + 补丁表；
  SPL 校验通过、跳进 shellcode，shellcode 把 payload 搬回原位、
  改掉目标指令，再跳回真正的入口。

本脚本针对的固件：
  uboot_b.bin 全文件 SHA256 = F0BA7AEC4D4FF8A9F51B8218A18253851A5ADC1FA12397703D4B03A221AE877F
  分区大小 0x300000 (3 MB)，payload 0x109ea0
  补丁点：code offset 0x6085C  (va 0xB506085C)
          原 0x35000160  ->  0xD503201F
  即 get_lock_status() 里 "cbnz w0, <锁定分支>" 改成 nop，
  让函数永远走"写入 1 = 已解锁"的路径。

如果你的固件哈希对不上：
  脚本会直接拒绝，不会写坏文件。此时需要按教程「固件不同怎么办」
  自行定位 get_lock_status 的 cbnz 指令，再用 --force-offset 指定。

用法：
  python build_unlock_image.py --input dump/uboot_b.bin --output out/uboot_b_magic64.img
  python build_unlock_image.py --input ... --output ... --force-offset 0xXXXXX --skip-hash-check
"""

import argparse
import hashlib
import os
import struct
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import magic_pack_ums9620 as MP

DHTB_HDR = 0x200
LOAD_BASE = 0xB5000000
PART_SIZE = 0x300000
NOP = 0xD503201F

STOCK_SHA256 = "f0ba7aec4d4ff8a9f51b8218a18253851a5adc1fa12397703d4b03a221ae877f"
DEFAULT_OFFSET = 0x6085C
EXPECT_WORD = 0x35000160


def die(msg, code=2):
    print("错误: " + msg, file=sys.stderr)
    sys.exit(code)


def main():
    ap = argparse.ArgumentParser(description="TYH831T / UMS9620 uboot magic64 解锁镜像生成")
    ap.add_argument("--input", required=True, help="原厂 uboot_b.bin（只读）")
    ap.add_argument("--output", required=True, help="输出的镜像路径")
    ap.add_argument("--offset", type=lambda x: int(x, 0), default=DEFAULT_OFFSET,
                    help="补丁点 code offset（默认 0x6085C）")
    ap.add_argument("--load-base", type=lambda x: int(x, 0), default=LOAD_BASE)
    ap.add_argument("--skip-hash-check", action="store_true", help="跳过整镜像哈希校验（不推荐）")
    ap.add_argument("--skip-word-check", action="store_true", help="跳过原指令校验（不推荐）")
    args = ap.parse_args()

    if not os.path.isfile(args.input):
        die("输入文件不存在: " + args.input)
    if os.path.abspath(args.input).lower() == os.path.abspath(args.output).lower():
        die("输出路径不能等于输入路径（不能覆盖原厂备份）")

    data = bytearray(open(args.input, "rb").read())
    print("输入  : %s" % os.path.abspath(args.input))
    print("大小  : %d (0x%x)" % (len(data), len(data)))

    if data[0:4] != b"DHTB":
        die("不是 DHTB 镜像（头部 = %r）" % bytes(data[0:4]))
    if len(data) != PART_SIZE:
        die("分区大小 0x%x，期望 0x%x —— 不是本机型镜像" % (len(data), PART_SIZE))

    size = struct.unpack_from("<I", data, 0x30)[0]
    foot = DHTB_HDR + size
    if data[foot:foot + 7] != b"SIMGHDR":
        die("在 0x%x 找不到 SIMGHDR 页脚 —— 镜像结构不符" % foot)
    if struct.unpack_from("<Q", data, foot + 0x18)[0] != 0x200:
        die("payload_offset 不是 0x200 —— 这个镜像可能已经打过 magic64")

    sha = hashlib.sha256(data).hexdigest()
    print("SHA256: %s" % sha)
    if not args.skip_hash_check:
        if sha != STOCK_SHA256:
            die("固件哈希与教程不符。\n"
                "  期望 %s\n  实际 %s\n"
                "这说明你的固件版本不同，不能直接套用本补丁点。\n"
                "请按教程「固件不同怎么办」重新定位，或使用 --skip-hash-check 自行承担风险。"
                % (STOCK_SHA256, sha))
        print("哈希  : 匹配（本教程验证过的固件）")

    file_off = DHTB_HDR + args.offset
    cur = struct.unpack_from("<I", data, file_off)[0]
    print("补丁点: code 0x%x  file 0x%x  当前指令 0x%08x" % (args.offset, file_off, cur))
    if not args.skip_word_check and cur != EXPECT_WORD:
        die("补丁点原指令不匹配（期望 0x%08x）—— 固件不同，停止。" % EXPECT_WORD)

    patches = [(args.offset, NOP)]
    img = MP.pack(data, patches, args.load_base)

    if len(img) != PART_SIZE:
        die("输出大小 0x%x != 0x%x" % (len(img), PART_SIZE))
    if img[0x210:0x210 + size] != bytes(data[DHTB_HDR:DHTB_HDR + size]):
        die("打包后 payload 与原厂不一致 —— 中止")

    with open(args.output, "wb") as f:
        f.write(img)

    print("")
    print("输出  : %s" % os.path.abspath(args.output))
    print("大小  : %d (0x%x)" % (len(img), len(img)))
    print("SHA256: %s" % hashlib.sha256(img).hexdigest())
    print("状态  : payload 逐字节未变（RSA 签名仍有效），仅追加 shellcode + 补丁表")
    return 0


if __name__ == "__main__":
    sys.exit(main())
