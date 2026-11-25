# ImmortalWrt 25.12 (MT7981B) 双机定制固件技术归档与小白保姆级使用教程
> **适用机型**：**ABT ASR3000 (安博通)** & **Qihoo 360T7 (奇虎 360T7)**  
> **系统基线**：`ImmortalWrt 25.12`｜**Linux 内核**：`6.12.74`｜**硬件平台**：`MediaTek Filogic MT7981B + MT7976C Wi-Fi 6`

---

## 目录
1. [双机硬件与出厂默认配置总览](#1-双机硬件与出厂默认配置总览)
2. [小白刷机与升级教程（Web UI 直刷 & U-Boot 刷机）](#2-小白刷机与升级教程web-ui-直刷--u-boot-刷机)
3. [日常使用：主路由模式 vs 旁路 AP 模式一键切换 (`switch-mode`)](#3-日常使用主路由模式-vs-旁路-ap-模式一键切换-switch-mode)
4. [双机 Mesh 组网教程（同地无缝漫游 & 异地内网互通）](#4-双机-mesh-组网教程同地无缝漫游--异地内网互通)
5. [仓库分支架构、公私分离机制与一键编译指南](#5-仓库分支架构公私分离机制与一键编译指南)

---

## 1. 双机硬件与出厂默认配置总览

本固件针对 **ABT ASR3000** 与 **Qihoo 360T7** 进行了深度内核与驱动级调优。两台设备刷入固件后，**默认均为「标准主路由模式」（WAN 口接光猫自动上网，LAN 口自建独立内网网段）**，开箱即用：

| 参数项 | ABT ASR3000 (安博通) | Qihoo 360T7 (奇虎 360) |
| :--- | :--- | :--- |
| **处理器 / 内存 / 闪存** | MT7981B (双核 A53 1.3GHz) / 256MB / 128MB SPI-NAND | MT7981B (双核 A53 1.3GHz) / 256MB / 128MB SPI-NAND |
| **分区布局 (安全大分区)** | **122.5MB UBI 大分区** + 独立 `art`/`factory`/`fip` 分区 | **108MB UBI 大分区 (`qihoo_360t7`)** + 独立 `Factory`/`fip` 分区 |
| **默认管理后台地址** | **`http://192.168.2.1`** | **`http://192.168.6.1`** |
| **默认登录账号 / 密码** | 用户名：`root` ｜ 密码：**无密码**（首次登录直接点登录） | 用户名：`root` ｜ 密码：**无密码**（首次登录直接点登录） |
| **物理 WAN 口 / LAN 口** | `WAN` 口 (`eth1`) 接光猫；`LAN1~LAN3` 接电脑/交换机 | `WAN` 口 (`wan`) 接光猫；`LAN1~LAN3` 接电脑/交换机 |
| **默认 IPv4 / IPv6 策略** | WAN 口自动 DHCPv4+DHCPv6；LAN 口开启 DHCP 与 IPv6 混合分配/中继 | WAN 口自动 DHCPv4+DHCPv6；LAN 口开启 DHCP 与 IPv6 混合分配/中继 |
| **公开版默认 Wi-Fi 名称** | `ASR3000_2.4G` / `ASR3000_5G` (160MHz 满血频宽) | `360T7_2.4G` / `360T7_5G` (160MHz 满血频宽) |
| **硬件加速与核心插件** | MTK HNAT 硬件加速 (`5 pps` 秒级绑定) + FullCone NAT + TCP BBR + OpenClash (Meta) + ZeroTier + Tailscale + WireGuard + DDNS-Go + UPnP + WOL 网络唤醒 + Argon 主题 | 同左（100% 完整对齐） |

---

## 2. 小白刷机与升级教程（Web UI 直刷 & U-Boot 刷机）

编译输出目录中同时提供 **`.bin`** 和 **`.itb`** 两种后缀的固件文件（内容完全相同，均包含完整的内核、SquashFS 根文件系统及机型签名元数据）：
- **ASR3000 固件**：`immortalwrt-mediatek-filogic-abt_asr3000-squashfs-sysupgrade.bin` (或 `.itb`)
- **360T7 固件**：`immortalwrt-mediatek-filogic-qihoo_360t7-squashfs-sysupgrade.bin` (或 `.itb`)

### 方式一：在 ImmortalWrt 网页后台直接升级（最简单，推荐日常升级使用）
1. 电脑连接路由器的 Wi-Fi 或 LAN 口，浏览器打开路由器后台（如 `http://192.168.2.1` 或 `http://192.168.6.1`，旁路 AP 模式下为 `http://192.168.10.2`）。
2. 点击左侧菜单 **「系统 (System)」 ➔ 「备份与升级 (Backup / Flash Firmware)」**。
3. 拉到页面最下方，点击 **「刷写新的固件... (Flash image...)」**。
4. 选择对应机型的 **`*-squashfs-sysupgrade.bin`**（或 `.itb`）文件上传：
   - **同版本日常小升级**：勾选“保留当前配置”，升级后所有设置不变；
   - **首次跨大版本升级（如从 21.02 升到 25.12）或想恢复默认主路由模式**：**取消勾选**“保留配置”，点击继续。
5. 等待约 **90 秒**，路由器自动重启后即可通过新内网地址登录。

---

### 方式二：升级大分区不死 U-Boot (`bl-mt798x-dhcpd`) 与 U-Boot 网页救砖刷机

如果你希望把 **360T7** 或 **ASR3000** 的底层 U-Boot 也升级为 **2025 最新版带 DHCP 自动发 IP 的不死网页大分区 U-Boot**：

#### 第一步：备份原机编程器分区（防砖铁律，必做！）
SSH 登录路由器后执行以下命令，把备份文件下载到电脑妥善保存：
```sh
cat /dev/mtd0 > /tmp/mtd0_bl2.bin
cat /dev/mtd1 > /tmp/mtd1_ubootenv.bin
cat /dev/mtd2 > /tmp/mtd2_factory.bin
cat /dev/mtd3 > /tmp/mtd3_fip.bin
```

#### 第二步：在系统中在线刷入新版大分区 U-Boot (`fip`)
将对应机型的 `nonmbm-fixed-parts` 版 U-Boot 上传至路由器 `/tmp/`：
- **ASR3000 专用 U-Boot**：`fip-mt7981_abt_asr3000_2025-Yuzhii-dhcpd-nonmbm-fixed-parts_*.bin`
- **360T7 专用 U-Boot**：`fip-mt7981_qihoo_360t7_2025-Yuzhii-dhcpd-nonmbm-fixed-parts_*.bin`

在路由器 SSH 中执行刷写（以 `fip` 分区为例）：
```sh
mtd write /tmp/fip-mt7981_*.bin fip
```
*(注：为什么选 `nonmbm-fixed-parts`？因为 ImmortalWrt 25.12 内核采用标准 Linux SPI-NAND + UBI 驱动且关闭了旧版联发科 NMBM 坏块表，使用 `nonmbm` 版 U-Boot 可直接挂载 `ubi` 分区中的 `fit` 卷正常启动系统。)*

#### 第三步：如何使用 U-Boot 网页后台刷机
1. 拔掉路由器电源，用网线将电脑连接到路由器任意 **LAN 口**（电脑网卡保持“自动获取 IP (DHCP)”即可，无需手动改固定 IP！）。
2. 用卡针按住路由器背面的 **Reset 复位孔不松手**，插上电源，等待 **5~8 秒**（看到指示灯变色或闪烁）后松开 Reset。
3. 打开电脑浏览器访问 **`http://192.168.1.1`**，即可进入中文/图形化 **U-Boot Web Failsafe 刷机页面**。
4. 点击选择文件，上传对应机型的 `*-squashfs-sysupgrade.bin` 或 `.itb`，点击 **Upload ➔ Update**，等待 2 分钟自动重启即完成刷机！

---

## 3. 日常使用：主路由模式 vs 旁路 AP 模式一键切换 (`switch-mode`)

固件内置了专为小白设计的 **`switch-mode`** 一键模式切换工具，通过 SSH 或网页后台的 **「系统 ➔ TTYD 终端」** 输入命令即可随时切换：

### 1. 查看当前路由器状态
```sh
switch-mode status
```
输出示例：
```text
================================================================
 设备型号   : ABT ASR3000 (abt,asr3000)
 当前模式   : 标准主路由模式 (Router Mode — WAN口 [eth1] 独立接光猫)
 br-lan网口 : lan1 lan2 lan3
 硬件WAN口  : eth1
 内网 IPv4  : 192.168.2.1
 DHCP服务端 : 已开启 (本机分配内网IP)
 硬件 HNAT  : 已加载 (mtkhnat)
 ZeroTier   : 200 info 4f490bee2b 1.16.2 ONLINE
================================================================
```

### 2. 切换为【标准主路由模式】（默认出厂状态：WAN 口接光猫，自建内网）
当把路由器放在独立住处、WAN 口插光猫 LAN 口时执行：
```sh
# 不填 IP 则自动使用机型默认网段（ASR3000 为 192.168.2.1，360T7 为 192.168.6.1）
switch-mode router

# 也可以自定义内网网段，例如改为 192.168.8.1：
switch-mode router 192.168.8.1
```
- **效果**：WAN 口自动从光猫获取 IPv4 和 IPv6；LAN1~LAN3 和 Wi-Fi 自动分配内网 IP 与 IPv6，并开启联发科 MT7981 硬件级 HNAT 千兆线速转发。

### 3. 切换为【二层桥接 AP / 旁路由 / 有线 Mesh 子节点模式】
当家里已经有主路由或光猫拨号（如 `192.168.10.1`），想把这台路由器当成 **无线 AP + 四口千兆交换机 + 旁路网关**（四个网口全盲插、不区分 WAN/LAN）时执行：
```sh
# 语法：switch-mode ap <本机IP> <上级主路由/光猫IP>
switch-mode ap 192.168.10.2 192.168.10.1
```
- **效果**：
  1. 机身全部 4 个网口（`WAN` + `LAN1~3`）全部合并进 `br-lan` 二层网桥，随便插哪个口都能用；
  2. 自动关闭本机 DHCPv4 与 IPv6 RA 广播，所有手机/电脑直接二层获取主路由/光猫分配的 IPv4 与原生 IPv6；
  3. 自动将 `wan6` 移入 `lan` 防火墙区域，消除内网网桥误触发 NAT 的问题；
  4. 本机上的 OpenClash、ZeroTier、Tailscale 依然保持正常在线。

---

## 4. 双机 Mesh 组网教程（同地无缝漫游 & 异地内网互通）

### 场景 A：同地组网 —— ASR3000 + 360T7 有线回程无缝漫游 Mesh (`802.11k/v/r`)
当你把 ASR3000 和 360T7 放在同一个家里扩展 Wi-Fi 覆盖时：
1. **主路由（例如 ASR3000）**：保持默认主路由模式（`192.168.2.1`），WAN 口接光猫。
2. **子路由（例如 360T7）**：用网线连接主路由 LAN 口与子路由任意网口，在子路由终端执行：
   ```sh
   switch-mode ap 192.168.2.2 192.168.2.1
   ```
   此时子路由变成 `192.168.2.2` 二层透明 AP，4 个网口均可盲插。
3. **一键同步双机 `802.11k/v/r` 快速漫游参数**：
   在两台路由器的终端分别执行同一条命令（如果你使用的是本地 `--private` 编译的固件，这一步在刷机时**已经自动配置好**，无需手动执行！）：
   ```sh
   switch-mode mesh-roaming MyHome_2.4G MyHome_5G 你的WiFi密码 a1b2
   ```
   完成后，手机/笔记本在两台路由器之间走动时将在 `< 50ms` 内自动完成 `802.11r/k/v` 硬件级无缝切换，视频通话与游戏不断线。

---

### 场景 B：异地组网 —— 两地独立宽带通过 ZeroTier 自动打通内网 Mesh
当 **ASR3000** 放在 A 地（内网 `192.168.2.0/24`），**360T7** 放在 B 地（内网 `192.168.6.0/24`）时：
1. 使用本地私有层（`--private`）编译的固件中，已经为两台机器分别预置了**独立的固定 ZeroTier 节点身份**并默认加入同一虚拟网络：
   - **ASR3000 节点 ID**：`4f490bee2b`
   - **360T7 节点 ID**：`557bed6749`
   - **ZeroTier 网络 ID**：`41d49af6c263f917`
2. 固件内置了 `/usr/bin/zerotier-fw4` 自动防火墙脚本，启动后会自动在 `nftables` (`fw4`) 中放行 ZeroTier 虚拟网卡与 `br-lan` 之间的双向转发与动态 NAT 伪装。
3. 你只需登录 [ZeroTier Central 控制台](https://my.zerotier.com/)：
   - 在 Members 列表中勾选授权 `4f490bee2b` (ASR3000) 和 `557bed6749` (360T7)；
   - 在 Managed Routes 中添加两条静态路由：
     - `192.168.2.0/24` via `<ASR3000 的 ZeroTier IP>`
     - `192.168.6.0/24` via `<360T7 的 ZeroTier IP>`
4. **效果**：无论两地是否有公网 IP，A 地内网的任何设备可以直接输入 `192.168.6.1` 访问 B 地路由器及内网 NAS/电脑，反之亦然！

---

## 5. 仓库分支架构、公私分离机制与一键编译指南

### 1. Git 仓库分支规划 (`git@github.com:Jesswjj/immortalwrt-mt798x.git`)
- **`openwrt-25.12`（通用主干分支）**：包含所有 MT7981B 通用底层补丁（macOS Apple Silicon M4 Pro 交叉编译修复、MT7981 HNAT + FullCone 补丁、`8021xd` 漫游守护进程修复、LED 驱动修复）、双机通用脚本（`switch-mode`、`zerotier-fw4`）及脱敏配置模板。
- **`asr3000-25.12`（ASR3000 专属分支）**：默认锁定 `.config` 为 `abt_asr3000`（默认 `192.168.2.1` 主路由模式）。
- **`360t7-25.12`（360T7 专属分支）**：默认锁定 `.config` 为 `qihoo_360t7`（108MB UBI 大分区安全布局，默认 `192.168.6.1` 主路由模式）。

### 2. 公开代码与个人隐私 100% 物理隔离机制
- **公开层（入库 Git）**：位于 `configs/common-files/`，不含任何个人 Wi-Fi 密码、机场订阅链接、ZeroTier 私钥或设备 MAC 地址，可安全开源分享。
- **私有层（`.gitignore` 严格忽略，绝不入库）**：位于本地 `files-private/`（及外部备份目录 `/Users/jesswu/Gitrepos/asr3000_backup/files-private/`），存放：
  - `common/etc/uci-defaults/98-private-secrets`：你的私人 Wi-Fi 密码、漫游域密钥、ZeroTier 网络号；
  - `common/etc/config/openclash` & `common/etc/openclash/`：你的 OpenClash 配置与 GeoIP/GeoSite 数据库；
  - `asr3000/etc/zerotier/` & `360t7/etc/zerotier/`：两台路由器各自独立的 `identity.secret` 私钥。

### 3. 一键编译命令 (`./build-router.sh`)
在源码根目录下执行：
```bash
# 1. 同时编译 ASR3000 和 360T7 两台机器的固件（自动注入本地私有配置，同时生成 .bin 和 .itb）
./build-router.sh all --private

# 2. 仅编译 ASR3000 固件
./build-router.sh asr3000 --private

# 3. 仅编译 360T7 固件
./build-router.sh 360t7 --private

# 4. 编译不带任何私人密码/密钥的纯公开分享版固件
./build-router.sh all --public
```
编译完成后，脚本会自动清理临时的 `files/` 目录，并将生成的 `.bin` 与 `.itb` 固件自动归档至 `/Users/jesswu/Gitrepos/asr3000_backup/release_25.12_and_uboot2025/`。
