RUYI = ruyi_plugin_rev(1)

load(
    "ruyi-plugin://internal-device-provisioner-common",
    _do_fastboot="do_fastboot",
    _do_fastboot_flash="do_fastboot_flash",
    _need_host_blkdevs_none="need_host_blkdevs_none",
)


#def _pretend_spacemit_k1(img_paths: PartitionMapDecl, _: PartitionMapDecl) -> list[str]:
def _pretend_spacemit_k1(img_paths, blkdev_paths):
    fsbl_path = img_paths["fsbl"]
    uboot_path = img_paths["uboot"]
    gpt_path = img_paths["gpt"]
    bootinfo_path = img_paths["bootinfo"]
    env_path = img_paths["env"]
    opensbi_path = img_paths["opensbi"]
    bootfs_path = img_paths["bootfs"]
    rootfs_path = img_paths["rootfs"]

    return [
        "load FSBL [yellow]" + fsbl_path + "[/] to device",
        "load U-Boot [yellow]" + uboot_path + "[/] to device",
        "flash [yellow]" + gpt_path + "[/] to partition [green]gpt[/]",
        "flash [yellow]" + bootinfo_path + "[/] to partition [green]bootinfo[/]",
        "flash [yellow]" + fsbl_path + "[/] to partition [green]fsbl[/]",
        "flash [yellow]" + env_path + "[/] to partition [green]env[/]",
        "flash [yellow]" + opensbi_path + "[/] to partition [green]opensbi[/]",
        "flash [yellow]" + uboot_path + "[/] to partition [green]uboot[/]",
        "flash [yellow]" + bootfs_path + "[/] to partition [green]bootfs[/]",
        "flash [yellow]" + rootfs_path + "[/] to partition [green]rootfs[/]",
    ]


#def _flash_spacemit_k1(img_paths: PartitionMapDecl, _: PartitionMapDecl) -> int:
def _flash_spacemit_k1(img_paths, blkdev_paths):
    # Perform the equivalent of the following commands:
    #
    # sudo fastboot stage factory/FSBL.bin
    # sudo fastboot continue
    # # Wait for 1 sec
    # sudo fastboot stage u-boot.itb
    # sudo fastboot continue
    # # Wait for 1 sec
    #
    # sudo fastboot flash gpt partition_universal.json
    # sudo fastboot flash bootinfo factory/bootinfo_sd.bin
    # sudo fastboot flash fsbl factory/FSBL.bin
    # sudo fastboot flash env env.bin
    # sudo fastboot flash opensbi fw_dynamic.itb
    # sudo fastboot flash uboot u-boot.itb
    # sudo fastboot flash bootfs bootfs.ext4
    # sudo fastboot flash rootfs rootfs.ext4
    #
    # See https://github.com/ruyisdk/ruyi/issues/289

    wait_secs = 1.0
    fsbl_img_path = img_paths["fsbl"]
    uboot_img_path = img_paths["uboot"]

    # Stage FSBL and continue
    RUYI.log.I("staging the FSBL image")
    ret = _do_fastboot("stage", fsbl_img_path)
    if ret != 0:
        RUYI.log.F("failed to stage FSBL image")
        return ret

    RUYI.log.I("continuing to execute staged FSBL")
    ret = _do_fastboot("continue")
    if ret != 0:
        RUYI.log.F("failed to continue execution with FSBL")
        return ret

    # Wait for 1 second
    RUYI.log.I("waiting " + str(wait_secs) + "s for the device to load FSBL")
    RUYI.sleep(wait_secs)

    # Stage u-boot and continue
    RUYI.log.I("staging the U-Boot image")
    ret = _do_fastboot("stage", uboot_img_path)
    if ret != 0:
        RUYI.log.F("failed to stage u-boot image")
        return ret
        
    RUYI.log.I("continuing to execute staged u-boot")
    ret = _do_fastboot("continue")
    if ret != 0:
        RUYI.log.F("failed to continue execution with U-Boot")
        return ret
        
    # Wait for 1 second
    RUYI.log.I("waiting " + str(wait_secs) + "s for the device to load U-Boot")
    RUYI.sleep(wait_secs)

    # Flash all partitions
    partitions = {
        "gpt": img_paths["gpt"],
        "bootinfo": img_paths["bootinfo"],
        "fsbl": img_paths["fsbl"],
        "env": img_paths["env"],
        "opensbi": img_paths["opensbi"],
        "uboot": img_paths["uboot"],
        "bootfs": img_paths["bootfs"],
        "rootfs": img_paths["rootfs"],
    }

    for partition, img_path in partitions.items():
        RUYI.log.I("flashing the [yellow]" + partition + "[/] partition")
        ret = _do_fastboot_flash(partition, img_path)
        if ret != 0:
            RUYI.log.F("failed to flash the [yellow]" + partition + "[/] partition")
            return ret

    return 0


#
# Device Provisioning Strategy Plugin Interface
#

_spacemit_k1_v1 = {
    "priority": 10,
    "need_host_blkdevs_fn": _need_host_blkdevs_none,
    "need_cmd": ["sudo", "fastboot"],
    "pretend_fn": _pretend_spacemit_k1,
    "flash_fn": _flash_spacemit_k1,
}

PROVIDED_DEVICE_PROVISION_STRATEGIES_V1 = {
    "spacemit-k1-v1": _spacemit_k1_v1,
}
