---
title: '新增板卡支持 (2024-01-15)'
---

# 新增板卡支持 (2024-01-15)

现已增加了以下的板卡镜像包：

* `board-image/buildroot-sdk-milkv-duo`: Milk-V Duo（非 256M 版本）的官方 Buildroot SDK
* `board-image/revyos-sg2042-milkv-pioneer`: 适用 Milk-V Pioneer（搭载 SG2042）的 RevyOS 系统镜像
* `board-image/revyos-sipeed-lpi4a`: 适用 Sipeed-V LicheePi 4A 的 RevyOS 系统镜像
* `board-image/uboot-sipeed-lpi4a-16g`: 适用 Sipeed LicheePi 4A (16G RAM) 的 U-Boot 镜像
* `board-image/uboot-sipeed-lpi4a-8g`: 适用 Sipeed LicheePi 4A (8G RAM) 的 U-Boot 镜像

您可用 `ruyi install` 安装它们：镜像文件会被自动解压或符号链接到 `~/.local/share/ruyi/blobs/<包名>-<包版本号>` 的位置。

感谢您对 RuyiSDK 的支持！
