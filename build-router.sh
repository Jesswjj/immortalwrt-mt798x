#!/usr/bin/env bash
# ==============================================================================
# build-router.sh: One-Click Firmware Builder for ABT ASR3000 & Qihoo 360T7
# Base: ImmortalWrt 25.12 (Linux 6.12.74, MediaTek Filogic MT7981B)
#
# Usage:
#   ./build-router.sh asr3000 [--private|--public]
#   ./build-router.sh 360t7   [--private|--public]
#   ./build-router.sh all     [--private|--public]
# ==============================================================================
set -e

TOPDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$TOPDIR"

TARGET_DEVICE="${1:-all}"
PRIV_MODE="${2:---private}"

# Locate private overlay directory (git-ignored) if available
if [ -d "$TOPDIR/files-private" ]; then
    PRIV_ROOT="$TOPDIR/files-private"
elif [ -d "/Users/jesswu/Gitrepos/asr3000_backup/files-private" ]; then
    PRIV_ROOT="/Users/jesswu/Gitrepos/asr3000_backup/files-private"
else
    PRIV_ROOT=""
fi

OUTPUT_ARCHIVE="/Users/jesswu/Gitrepos/asr3000_backup/release_25.12_and_uboot2025"
[ -d "$OUTPUT_ARCHIVE" ] || OUTPUT_ARCHIVE="$TOPDIR/bin/releases"
mkdir -p "$OUTPUT_ARCHIVE"

# Activate macOS / Linux build environment
if [ -f "$TOPDIR/build-env.sh" ]; then
    source "$TOPDIR/build-env.sh"
fi

prepare_overlay() {
    local dev="$1"
    rm -rf "$TOPDIR/files"
    mkdir -p "$TOPDIR/files"

    echo "📦 [1/3] 注入公开通用配置层 (configs/common-files/)..."
    cp -a "$TOPDIR/configs/common-files/." "$TOPDIR/files/"

    if [ "$PRIV_MODE" != "--public" ] && [ -n "$PRIV_ROOT" ] && [ -d "$PRIV_ROOT" ]; then
        echo "🔒 [2/3] 注入本地私有密钥与订阅配置层 ($PRIV_ROOT -> $dev)..."
        if [ -d "$PRIV_ROOT/common" ]; then
            cp -a "$PRIV_ROOT/common/." "$TOPDIR/files/"
        fi
        if [ -d "$PRIV_ROOT/$dev" ]; then
            cp -a "$PRIV_ROOT/$dev/." "$TOPDIR/files/"
        fi
    else
        echo "🌐 [2/3] 使用纯公开脱敏模式 (--public)，不注入任何私人密钥..."
    fi
}

build_single_device() {
    local dev="$1"
    local defcfg="$TOPDIR/configs/${dev}.defconfig"
    local img_prefix=""
    if [ "$dev" = "asr3000" ]; then
        img_prefix="immortalwrt-mediatek-filogic-abt_asr3000"
    elif [ "$dev" = "360t7" ]; then
        img_prefix="immortalwrt-mediatek-filogic-qihoo_360t7"
    else
        echo "❌ 未知机型: $dev (仅支持 asr3000 | 360t7 | all)"
        exit 1
    fi

    echo "========================================================================"
    echo "🚀 开始编译机型: $dev ($img_prefix)"
    echo "========================================================================"

    prepare_overlay "$dev"

    cp -f "$defcfg" "$TOPDIR/.config"
    make defconfig >/dev/null

    echo "🔨 [3/3] 正在打包内核与 SquashFS 固件镜像..."
    make target/linux/install -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"

    local bin_dir="$TOPDIR/bin/targets/mediatek/filogic"
    local itb_file="${bin_dir}/${img_prefix}-squashfs-sysupgrade.itb"
    local bin_file="${bin_dir}/${img_prefix}-squashfs-sysupgrade.bin"

    if [ -f "$itb_file" ]; then
        # 同时生成可直接用于 ImmortalWrt Web UI 与 U-Boot Web UI 升级的 .bin 格式固件
        cp -f "$itb_file" "$bin_file"
        cp -f "$itb_file" "$OUTPUT_ARCHIVE/${img_prefix}-squashfs-sysupgrade.itb"
        cp -f "$bin_file" "$OUTPUT_ARCHIVE/${img_prefix}-squashfs-sysupgrade.bin"
        echo "✅ 编译成功:"
        ls -lh "$itb_file" "$bin_file"
    else
        echo "❌ 未找到生成的固件文件: $itb_file"
        exit 1
    fi

    # 编译完成后清理临时 files/ 目录，确保工作区绝对干净不残留私钥
    rm -rf "$TOPDIR/files"
}

case "$TARGET_DEVICE" in
    asr3000)
        build_single_device "asr3000"
        ;;
    360t7)
        build_single_device "360t7"
        ;;
    all)
        build_single_device "asr3000"
        build_single_device "360t7"
        ;;
    *)
        echo "用法: $0 [asr3000|360t7|all] [--private|--public]"
        exit 1
        ;;
esac

echo "🎉 全部固件编译与归档完成！输出目录: $OUTPUT_ARCHIVE"
