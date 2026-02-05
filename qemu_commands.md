# QEMU CLI 命令整理

本文档整理了常用的 QEMU 命令行选项，旨在为开发类似 VirtualBox 的 QEMU 前端提供参考。

## 1. 基础运行与机器配置

| 命令选项 | 说明 | 示例 |
| :--- | :--- | :--- |
| `-h`, `--help` | 显示帮助信息 | `qemu-system-x86_64 -h` |
| `-version` | 显示 QEMU 版本 | `qemu-system-x86_64 -version` |
| `-machine [type=]name` | 选择模拟的机器类型 (常用: `q35`, `pc`) | `-machine q35` |
| `-accel <accel>` | 选择加速器 (`kvm`, `hvf`, `tcg`, `whpx`) | `-accel kvm` |
| `-m <size>` | 设置虚拟机内存大小 | `-m 4G` |
| `-smp <n>` | 设置 CPU 核心数 | `-smp 4` |
| `-cpu <model>` | 指定 CPU 模型 (常用: `host`, `max`) | `-cpu host` |

## 2. 磁盘与存储

| 命令选项 | 说明 | 示例 |
| :--- | :--- | :--- |
| `-drive file=<path>,format=<fmt>` | 定义驱动器（旧式，但灵活） | `-drive file=win10.qcow2,format=qcow2` |
| `-hda <file>` | 设置第一个硬盘映像 | `-hda disk.img` |
| `-cdrom <file>` | 设置光驱 ISO 映像 | `-cdrom ubuntu.iso` |
| `-boot [order=]` | 设置启动顺序 (d: CD-ROM, c: Hard Disk) | `-boot order=dc` |
| `-device virtio-blk-pci,...` | 使用 virtio 现代方式挂载磁盘 | `-device virtio-blk-pci,drive=drive0` |

## 3. 网络配置

| 命令选项 | 说明 | 示例 |
| :--- | :--- | :--- |
| `-netdev user,id=<id>` | 创建用户模式网络后端 (SLIRP) | `-netdev user,id=net0` |
| `hostfwd=tcp::<hport>-:<gport>` | **端口映射** (在 -netdev user 后跟) | `-netdev user,id=n0,hostfwd=tcp::2222-:22` |
| `smb=<path>` | **内置 SMB 共享** (仅限 -netdev user) | `-netdev user,id=n0,smb=/home/user/share` |
| `-netdev tap,id=<id>` | 创建 TAP 网络后端 (需要 root/bridge) | `-netdev tap,id=net0` |
| `-device <model>,netdev=<id>` | 添加网卡并关联后端 (`virtio-net-pci`) | `-device virtio-net-pci,netdev=net0` |
| `-nic user,model=virtio` | 简化的网卡与后端配置方式 | `-nic user,model=virtio-net-pci` |

## 4. 图形与显示

| 命令选项 | 说明 | 示例 |
| :--- | :--- | :--- |
| `-display <type>` | 设置显示输出方式 (`gtk`, `sdl`, `vnc`, `none`) | `-display gtk` |
| `-vga <type>` | 指定显卡类型 (`virtio`, `std`, `vmware`, `qxl`) | `-vga virtio` |
| `-vnc <display>` | 启用 VNC 服务 | `-vnc :1` |
| `-nographic` | 禁用图形输出，将串口重定向到控制台 | `-nographic` |

## 5. 输入设备与外设

| 命令选项 | 说明 | 示例 |
| :--- | :--- | :--- |
| `-usb` | 启用 USB 控制器 | `-usb` |
| `-device usb-tablet` | 添加 USB 绝对定位设备（解决鼠标偏移） | `-device usb-tablet` |
| `-device usb-host,hostbus=<bus>,hostaddr=<addr>` | USB 设备透传 | `-device usb-host,hostbus=1,hostaddr=2` |

## 6. 其他常用选项

| 命令选项 | 说明 | 示例 |
| :--- | :--- | :--- |
| `-monitor <device>` | 设置 QEMU Monitor (控制台) | `-monitor stdio` |
| `-snapshot` | 启用快照模式 (不保存更改到磁盘文件) | `-snapshot` |
| `-no-reboot` | 客户机重启时退出 QEMU | `-no-reboot` |
| `-enable-kvm` | 简写形式：启用 KVM 加速 | `-enable-kvm` |

## 7. 磁盘镜像管理 (qemu-img)

作为前端，你还需要调用 `qemu-img` 来管理磁盘文件。

| 命令 | 说明 | 示例 |
| :--- | :--- | :--- |
| `create` | 创建新镜像 | `qemu-img create -f qcow2 disk.qcow2 20G` |
| `info` | 查看镜像信息 | `qemu-img info disk.qcow2` |
| `convert` | 转换格式 (如 vmdk 转 qcow2) | `qemu-img convert -f vmdk -O qcow2 win.vmdk win.qcow2` |
| `resize` | 调整镜像大小 | `qemu-img resize disk.qcow2 +10G` |
| `snapshot` | 管理内部快照 | `qemu-img snapshot -c backup disk.qcow2` |
| `check` | 检查镜像一致性与损坏 | `qemu-img check disk.qcow2` |
| `rebase` | 改变后端文件 (用于瘦镜像) | `qemu-img rebase -b new_base.qcow2 disk.qcow2` |

## 8. 音频配置

| 命令选项 | 说明 | 示例 |
| :--- | :--- | :--- |
| `-audiodev <driver>,id=<id>` | 定义音频后端 (`pa`, `sdl`, `alsa`, `oss`) | `-audiodev pa,id=snd0` |
| `-device <model>,audiodev=<id>` | 添加声卡硬件 (`intel-hda`, `AC97`) | `-device intel-hda -device hda-duplex,audiodev=snd0` |

## 9. 共享文件夹

### A. VirtFS (9p) - 推荐 Linux 客户机
需要客户机内核支持 9p。

| 命令选项 | 说明 | 示例 |
| :--- | :--- | :--- |
| `-virtfs local,path=<path>,mount_tag=<tag>,security_model=passthrough,id=<id>` | 定义共享目录 | `-virtfs local,path=/tmp/share,mount_tag=v_share,security_model=passthrough,id=fs0` |

**客户机内挂载:** `mount -t 9p -o trans=virtio v_share /mnt/shared`

### B. SMB (内置) - 推荐 Windows 客户机
依赖宿主机安装了 `samba`。

| 命令选项 | 说明 | 示例 |
| :--- | :--- | :--- |
| `-netdev user,id=n1,smb=/path/to/share` | 映射目录为 SMB 共享 | `-netdev user,id=n1,smb=/home/user/data` |

**客户机内访问:** 在 Windows 中访问 `\10.0.2.4\qemu`

## 10. 调试与管理 (高级)

| 命令选项 | 说明 | 示例 |
| :--- | :--- | :--- |
| `-S` | 启动时暂停 CPU (等待 monitor 命令) | `-S` |
| `-s` | 简写形式：在 1234 端口开启 GDB 调试 | `-s` |
| `-gdb dev` | 在指定设备开启 GDB 调试 | `-gdb tcp::1234` |
| `-d <item1>,...` | 开启日志输出 (如 `cpu`, `int`, `guest_errors`) | `-d guest_errors` |
| `-D <logfile>` | 指定日志输出文件 | `-D qemu.log` |

---

## 常用组合示例 (极简启动)

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -smp 4 \
  -cpu host \
  -drive file=test.qcow2,format=qcow2 \
  -cdrom install.iso \
  -boot d \
  -vga virtio \
  -display gtk \
  -nic user,model=virtio-net-pci
```
