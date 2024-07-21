---
title: '尝鲜：使用 Box64 在 RISC-V 系统上运行 WPS Office'
---

# 尝鲜：使用 Box64 在 RISC-V 系统上运行 WPS Office

得益于 Box64 RISC-V 移植工作的进展，在 RISC-V Linux 桌面发行版上运行 WPS
Office 等常见 x86 二进制软件已成为可能。RuyiSDK 正在开展此方面的集成工作；
按以下的步骤操作，您将能先行一步感受 RISC-V 办公体验。

我们假定您在进行以下操作之前，已经升级到了 `ruyi` 0.14.0 或更高的版本，
并执行了 `ruyi update` 以将软件源信息同步到最新。

## 操作步骤

为叙述方便，设您的 `$HOME` 为 `/home/foo`，架构（`uname -m` 输出）为
`riscv64`，使用 `sudo` 提权。

### 安装 Box64

按照 RuyiSDK 软件包的命名习惯，从 Box64 的上游（而非 PLCT 或某些厂商的 fork）
构建的 Box64 二进制包，名字叫 `box64-upstream`。

```sh
ruyi install box64-upstream
# ...
# info: package box64-upstream-0.3.0-ruyi.20240718 installed to /home/foo/.local/share/ruyi/binaries/riscv64/box64-upstream-0.3.0-ruyi.20240718
```

记下安装路径。

### 配置 Linux `binfmt_misc` 机制

由于 WPS Office 的打包方式特殊，它只能从开发商提供的启动器脚本被间接拉起，
而不能直接交由 Box64 启动。因此您需要确保您的系统支持 `binfmt_misc`：
如果不支持，接下来的操作会失败。

不同 Linux 发行版的 `binfmt_misc` 配置方式不尽相同，以下针对采用 systemd
的系统叙述。您可以根据自身情况自行调整。


```sh
# 确认 Box64 可执行文件的位置
ls /home/foo/.local/share/ruyi/binaries/riscv64/box64-upstream-0.3.0-ruyi.20240718/bin/box64

# 调整 Box64 `binfmt.d` 配置文件的路径
# 假设您使用 nano 编辑器
nano /home/foo/.local/share/ruyi/binaries/riscv64/box64-upstream-0.3.0-ruyi.20240718/etc/binfmt.d/box64.conf
# 将行尾的 //bin/box64 改为先前验证过的绝对路径

# 将其部署到系统
sudo cp /home/foo/.local/share/ruyi/binaries/riscv64/box64-upstream-0.3.0-ruyi.20240718/etc/binfmt.d/box64.conf /etc/binfmt.d/box64.conf
sudo systemctl restart systemd-binfmt

# 检查部署结果
cat /proc/sys/fs/binfmt_misc/box64
```

请注意：如果您在做这些操作之前，已经配置过 QEMU linux-user 等其他的 x86
模拟机制，您需要禁用它们才能在后续的步骤中成功利用 Box64。如果您决定这么做，
请不要忘记在使用结束之后恢复先前的配置。

### 安装 x86 sysroot

由于 Box64 主要面向游戏等软件的模拟，而这些软件基本都自带所有依赖，所以 Box64
本身基本没有自带什么 x86 运行时库。WPS Office 作为一个预期被系统包管理器管理的
桌面应用，Box64 自带的少量 x86 运行时库无法满足它的需求，因此我们需要自行准备
x86 环境。

```sh
# 下载预制的 x86 sysroot
# 此为临时性的链接。后续待本功能迭代稳定之后，操作方式将改变，此链接也将失效
# 假设此文件放在了 ~/Downloads 目录下
wget https://mirror.iscas.ac.cn/ruyisdk/dist/temp/debian-buster.gui.20240721.amd64.tar.zst

# 假设安装到 /opt/debian-buster.amd64
sudo mkdir /opt/debian-buster.amd64
pushd /opt/debian-buster.amd64
tar -xf ~/Downloads/debian-buster.gui.20240721.amd64.tar.zst
popd
```

### 安装 WPS Office

强制安装 `x86_64` 架构的 WPS Office 软件包：

```sh
ruyi install --host x86_64 wps-office
# ...
# info: package wps-office-11.1.0-r.11720 installed to /home/foo/.local/share/ruyi/binaries/x86_64/wps-office-11.1.0-r.11720
```

由于 WPS Office 官方下载页面的限制，`ruyi` 无法自动下载安装包。
请按照提示信息操作，之后重新执行该命令以安装。

### 调整 WPS Office 启动器脚本

由于 WPS Office 预期自身被系统包管理器管理，它的启动器脚本假定了自身的安装路径
为 `/opt/kingsoft/wps-office`，需要为它们打补丁。

```sh
pushd /home/foo/.local/share/ruyi/binaries/x86_64/wps-office-11.1.0-r.11720

# 当前工作目录路径中应当不含特殊字符。
# 如果含有，请自行适当调整 sed 命令的参数
sed -i "s@gInstallPath=/@gInstallPath=$(pwd)/@" ./usr/bin/*

# 可选: 使 WPS 与 Box64 的日志信息能够被看到
sed -i "s@ > /dev/null 2>&1@@" ./usr/bin/*

popd
```

### 运行 WPS Office

准备工作终于完成，现在将所有部分串起来：

```sh
# 此动态链接库的原生转发仍有些问题，因此强制以模拟方式执行
export BOX64_EMULATED_LIBS=libsqlite3.so.0
# 配置 Box64 库搜索路径
export BOX64_LD_LIBRARY_PATH=/opt/debian-buster.amd64/usr/lib/x86_64-linux-gnu

# 现在可以执行了！
/home/foo/.local/share/ruyi/binaries/x86_64/wps-office-11.1.0-r.11720/usr/bin/wps
```

## 结语

以上是 RuyiSDK 对 RISC-V 二进制翻译 x86 软件的初步集成成果。
今后我们仍将迭代这一过程的用户体验，以期用户在 RISC-V 系统上运行需要的应用
更加方便。
