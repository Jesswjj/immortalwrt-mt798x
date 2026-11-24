# ABT ASR3000 (MT7981) 固件生态、编译环境与救砖全攻略

> **整理日期**：2026-11-24  
> **维护账号**：`Jesswjj <317417277@qq.com>`  
> **适用机型**：ABT ASR3000 (MediaTek MT7981B / Filogic 820, ARM Cortex-A53 双核 1.3GHz, 256MB DDR3, 128MB SPI-NAND)

---

## 一、路由器当前硬件与分区状态档案

### 1. 基础网络与硬件信息
* **设备型号**：`ABT ASR3000` (`compatible = "abt,asr3000", "mediatek,mt7981"`)
* **当前管理地址**：`http://192.168.10.2`（上游光猫：`http://192.168.10.1`）
* **无线规格**：AX3000（2.4GHz 2T2R 574Mbps + 5GHz 2T2R/3T3R 160MHz HE160 2402Mbps）
* **当前运行系统**：ImmortalWrt 21.02-SNAPSHOT (`r19228-022c1ef978`, Linux `5.4.246`)
* **已执行在线优化**：
  1. 清理了失效的 `network.utun` (`192.168.10.110`) 双 IP 冲突，消除了 `eth1` ARP 广播风暴。
  2. 彻底禁用并卸载了每秒 fork 数十次导致单核 25% CPU 满载的 `wrtbwmon` / `luci-app-wrtbwmon`。
  3. 保留 `ABT_5G` 无线 `HE160` 160MHz 满血频宽。

### 2. 原厂 Flash 分区表结构（128MB SPI-NAND + NMBM）
当前路由器内部采用经典的 **QWRT / 21.02 NMBM 分区表**（`ubi` 大小 `113152k` / `110.5 MB`）：

| MTD 分区 | 偏移与大小 (Hex) | 容量 | 分区名称 | 说明与已备份文件名 |
| :--- | :--- | :---: | :--- | :--- |
| `mtd0` | `0x0000000 - 0x7400000` | 116 MB | `spi0.0` | NMBM 映射全盘 |
| `mtd1` | `0x0000000 - 0x0100000` | 1.0 MB | `BL2` | 第一阶段预引导 (`mtd1_BL2.bin`) |
| `mtd2` | `0x0100000 - 0x0180000` | 512 KB | `u-boot-env` | U-Boot 环境变量 (`mtd2_u-boot-env.bin`, `mtd_layout_label=QWRT`) |
| `mtd3` | `0x0180000 - 0x0280000` | 1.0 MB | `art` | 产测与基础 MAC 校准 (`mtd3_art.bin`) |
| `mtd4` | `0x0280000 - 0x0380000` | 1.0 MB | `Factory` | **核心无线 EEPROM 射频校准与 MAC** (`mtd4_Factory.bin`) |
| `mtd5` | `0x0380000 - 0x0580000` | 2.0 MB | `FIP` | U-Boot 主程序 (`2022.07-rc3`, `mtd5_FIP.bin`) |
| `mtd6` | `0x0580000 - 0x7400000` | **110.5 MB** | `ubi` | 固件内核 (`kernel`) + 根文件系统 (`rootfs` / `rootfs_data`) |

* **本地备份存放路径**：`/Users/jesswu/Gitrepos/asr3000_backup/`
  * `mtd1_BL2.bin` (SHA256: `b920416eefc85fb9efed9a645a9e9195079432aa5c6f18e767b56b228beeba19`)
  * `mtd2_u-boot-env.bin` (SHA256: `b2e43fb5a811ba1537c20fd3e2d48f6e861ce46f6c5368952f59ef3850c5bd40`)
  * `mtd3_art.bin` (SHA256: `c4eed2c3c0e3a20df1de3f06299ff792d03744d512ef1615800368fd67c92085`)
  * `mtd4_Factory.bin` (SHA256: `58db165f03f8e0ab252256dd59f076c5b3e3021faeb9aa3682e43ef16b40118b`)
  * `mtd5_FIP.bin` (SHA256: `9f95fdc3038fa75fd72ed241f3f19015f4cb42989e83440529bf5b20d5aa30b1`)
  * `etc_config_backup.tar.gz` (SHA256: `9db954d4310e7dfbe4424732826c297331727160be3830e9c7a89f8769be7184`)

---

## 二、主流 MT798x 开源/闭源固件与 U-Boot 仓库横向对比

### 1. 四大核心仓库全维度对比表

| 仓库地址 | OpenWrt 版本 / 内核 | 无线驱动方案 | 最近更新 | ASR3000 分区表与刷机方式 | 核心优缺点与适用场景 |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **[`padavanonly/immortalwrt-mt798x`](https://github.com/padavanonly/immortalwrt-mt798x)**<br>*(已 Fork 至 [`Jesswjj/immortalwrt-mt798x`](https://github.com/Jesswjj/immortalwrt-mt798x))* | ImmortalWrt **21.02**<br>Linux **5.4.246** | 联发科闭源 `mt_wifi`<br>`v7.6.6.1` | 2024-11 | **100% 兼容当前 U-Boot**<br>`ubi: 113152k (0x6e80000)`<br>`.bin` 网页后台直接无损升级 | **当前机器原装同源系统**：含 `padavanonly` 针对 HNAT 的定制优化，已在本地 M4 Pro 编译通过。 |
| **[`hanwckf/immortalwrt-mt798x`](https://github.com/hanwckf/immortalwrt-mt798x)** | ImmortalWrt **21.02**<br>Linux **5.4.284** | 联发科闭源 `mt_wifi`<br>**`v7.6.7.3-20250408`** | **2026-09** | **100% 兼容当前 U-Boot**<br>`ubi: 113152k (0x6e80000)`<br>`.bin` 网页后台直接无损升级 | **21.02 闭源驱动官方鼻祖（1800+ Stars）**：<br>• 内核升至 `5.4.284`<br>• 闭源无线驱动升至 **2025 年最新 `7.6.7.3`**（支持 MLR 远距离传输、修复 iwinfo 内存越界与 use-after-free）<br>• 新增 MT7981 千兆网口 GPHY 校准与 PPE1 硬加速重置修复。 |
| **[`padavanonly/immortalwrt-mt798x-6.6`](https://github.com/padavanonly/immortalwrt-mt798x-6.6)** | ImmortalWrt **24.10**<br>Linux **6.6 LTS** | • `openwrt-24.10-6.6`：开源 `mt76`<br>• `mt798x-mt799x-6.6-mtwifi`：闭源 `mt_wifi` | **2026-07** | • `openwrt-24.10-6.6` 分支：`ubi: 0x6e80000`（兼容当前 U-Boot）<br>• `mtwifi` 分支：`ubi: 0x7a80000` (`.itb` 格式，需刷支持 fit 的 U-Boot) | **6.6 LTS 主力新内核**：<br>• 升级至 `fw4 (nftables)` + GCC 13 工具链<br>• 适合需要 Linux 6.6 新内核特性（BPF/Docker/BBRv3）及 24.10 新版插件源的场景。 |
| **[`chasey-dev/immortalwrt-mt798x-rebase`](https://github.com/chasey-dev/immortalwrt-mt798x-rebase)** | ImmortalWrt **25.12**<br>Linux **6.12 LTS** | 联发科闭源 `mt_wifi`<br>**`v7.6.7.3` + 2026-06 最新固件** | **2026-11** | 采用 **`fit (sysupgrade.itb)` 大分区表 (`0x7a80000`)**<br>**必须配合新版支持 `fit` 的 U-Boot 刷入** | **全网最新前沿版本**：<br>• 同步联发科官方最新 `mtk-openwrt-feeds` (Kernel 6.12 PPE/HNAT)<br>• 引入全新的 `mtwifi-cfg-ucode` 原生配置架构<br>• 兼具 **Linux 6.12 最新内核 + 闭源无线驱动**。 |
| **[`Yuzhii0718/bl-mt798x-dhcpd`](https://github.com/Yuzhii0718/bl-mt798x-dhcpd)** | **U-Boot 2025 + ATF** | 底层 Bootloader | **2026-10** | 原生提供 ASR3000 三套配置：<br>1. `configs/` (标准 NMBM `113152k`)<br>2. `configs-nonmbm/` (去 NMBM)<br>3. `configs-fit/` (支持 `24.10`/`25.12` `.itb`) | **ASR3000 终极救砖 U-Boot**：<br>• **自带 DHCP 服务**（捅 Reset 进 U-Boot 电脑无需手动配静态 IP）<br>• 现代化多语言 WebUI，支持网页端备份/刷写 Flash、修改环境变量、管理 UBI 分区、甚至支持 DDR3 超频 BL2。 |

---

### 2. 核心技术路线总结：如何选择？

1. **追求“免刷 U-Boot + 最强闭源 Wi-Fi 信号 + 最极致稳定”**：
   * 首选 **`hanwckf/immortalwrt-mt798x` (`openwrt-21.02`, Linux `5.4.284` + `mt_wifi v7.6.7.3`)** 或我们已编译好的 `Jesswjj/immortalwrt-mt798x` 并合入 `hanwckf` 的最新 `5.4.284` / `mt_wifi 7.6.7.3` 更新。
   * 原因：联发科官方针对 MT7981 的原厂 SDK 基准就是 Linux 5.4，其闭源驱动 `mt_wifi` 经过数年打磨，在 160MHz 频宽、苹果设备唤醒及弱信号抗干扰上最为成熟，且与你机器现有的 U-Boot 分区表 100% 吻合。
2. **追求“最新 Linux 6.6 / 6.12 内核 + 闭源无线驱动”**：
   * 推荐 **`padavanonly/immortalwrt-mt798x-6.6` (`mt798x-mt799x-6.6-mtwifi`)** 或 **`chasey-dev/immortalwrt-mt798x-rebase` (`25.12`, Linux 6.12)**。
   * 注意事项：这两个新内核闭源驱动分支对 `abt_asr3000` 均采用了新版 OpenWrt 标准 **`fit` (`sysupgrade.itb`) 动态分区格式 (`ubi` 起点 `0x580000`，长度扩展至 `0x7a80000`)**。如果要刷这两个分支，需要先刷入 **`Yuzhii0718/bl-mt798x-dhcpd`** 中对应的 `configs-fit/mt7981_abt_asr3000_defconfig` 版 U-Boot。

---

## 三、本地 macOS (Apple Silicon M4 Pro) 编译环境与成果记录

### 1. 本地编译环境架构
* **区分大小写编译盘镜像**：`/Users/jesswu/Gitrepos/OpenWrtBuild.sparseimage`（60GB APFS 区分大小写动态磁盘镜像）
* **挂载路径**：`/Users/jesswu/Gitrepos/openwrt-env`
* **源码路径**：`/Users/jesswu/Gitrepos/openwrt-env/immortalwrt-mt798x`（软链接：`/Users/jesswu/Gitrepos/immortalwrt-mt798x`）
* **一键环境加载脚本**：`/Users/jesswu/Gitrepos/immortalwrt-mt798x/build-env.sh`
  ```bash
  cd /Users/jesswu/Gitrepos/immortalwrt-mt798x
  source ./build-env.sh
  make -j14
  ```

### 2. 已攻克的 macOS (M4 Pro / Xcode Clang) 5 项交叉编译补丁（已推送至 `Jesswjj/immortalwrt-mt798x`）
1. `tools/zlib/patches/100-macos-fdopen.patch` & `toolchain/gcc/patches/8.4.0/999-macos-zlib-fdopen.patch` & `toolchain/binutils/patches/2.34/900-macos-zlib-fdopen.patch`：修复旧版 `zlib` 在 `TARGET_OS_MAC` 下将 `fdopen` 宏定义为 `NULL` 破坏 macOS SDK `<stdio.h>` 的问题。
2. `toolchain/gcc/patches/8.4.0/997-macos-libc++-before-safe-ctype.patch`：修复 `gcc/system.h` 中 `safe-ctype.h` 宏污染 macOS `libc++` `<locale>` 头文件的问题。
3. `toolchain/gcc/patches/8.4.0/998-macos-arm64-host-hooks.patch`：为 GCC 8.4 增加 `arm-apple-darwin*` Host Hook，并将 PCH 内存对齐从 `4096` (4KB) 修正为 Apple Silicon 的 `16384` (16KB)，解决 `xgcc` 运行时 `munmap` 崩溃；同时使用 `#ifdef IN_TARGET_CODE` 隔离 `aarch64.h` 目标宏。
4. `rules.mk`：在 `IS_PACKAGE_BUILD` 阶段保留 `-L$(STAGING_DIR_HOSTPKG)/lib -L$(STAGING_DIR)/host/lib`，确保 Host 工具正确链接 `libintl`。
5. `feeds/packages/net/zerotier/patches/0006-aarch64-crypto-arch-directive.patch`：为 `AES_armcrypto.cpp` 显式声明 `__asm__(".arch armv8-a+crypto")`，启用 MT7981 硬件 AES 加密指令集。

### 3. 已编译完成的定制固件产物 (`21.02`)
* **输出目录**：`/Users/jesswu/Gitrepos/immortalwrt-mt798x/bin/targets/mediatek/mt7981/`
* **升级包文件**：`immortalwrt-mediatek-mt7981-abt_asr3000-squashfs-sysupgrade.bin` (21 MB)
  * **SHA256**：`71af3cf54be356e4d3ef6c838348216c496bd9be242dd9a19290186b79f5c428`
* **救砖底包**：`immortalwrt-mediatek-mt7981-abt_asr3000-squashfs-factory.bin` (23 MB)
  * **SHA256**：`5e8dffe1ff8f80d7e32cbdd19c2be959db82353fd6c5df339cf7e96a3c060707`
* **已集成的定制功能与插件**：
  * **核心与硬加速**：`kmod-mt_wifi` + `luci-app-mtwifi-cfg`、`luci-app-turboacc-mtk` (`kmod-mediatek_hnat` + `kmod-warp` + BBR)、`luci-app-eqos-mtk`、`luci-app-upnp`
  * **GitHub/Steam 免费加速与分流**：`luci-app-smartdns`、`luci-app-openclash`、`luci-app-wireguard` (`kmod-wireguard` + `wireguard-tools`)
  * **异地组网与远程管理**：`luci-app-zerotier`、`luci-app-ddns` (含阿里云 & Cloudflare)、`luci-app-aliddns`、`luci-app-wol`
  * **系统工具与主题**：`luci-app-nlbwmon` (替代卡顿的 `wrtbwmon`)、`luci-app-ttyd`、`luci-app-autoreboot`、`luci-app-filetransfer`、`luci-theme-argon` + `luci-app-argon-config`
