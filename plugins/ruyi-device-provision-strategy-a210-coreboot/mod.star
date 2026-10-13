RUYI = ruyi_plugin_rev(1)

load(
    "ruyi-plugin://internal-device-provisioner-common",
    _do_fastboot="do_fastboot",
    _need_host_blkdevs_none="need_host_blkdevs_none",
)

load(
    "ruyi-plugin://internal-i18n-compat",
    _msg="msg",
)


def _m(msgid):
    ret = _msg("plugins/ruyi-device-provision-strategy-std/" + msgid)
    if not ret:
        ret = _msg("plugins/ruyi-device-provision-strategy-spacemit-k1/" + msgid)
    if not ret:
        ret = _msg("plugins/ruyi-device-provision-strategy-a210-coreboot/" + msgid)

    return ret


#def _flash_partition(part: str, img_path: str, disable_sparse: bool) -> int:
def _flash_partition(part, img_path, disable_sparse):
    RUYI.log.I(_m("flashing-partition").format(part=part))
    if disable_sparse:
        # `-S 0` disables sparse flashing, as recommended by the firmware
        # documentation for the BootROM and emmc0boot0 targets.
        ret = _do_fastboot("-S", "0", "flash", part, img_path)
    else:
        # The full disk image is written with sparse flashing left enabled.
        ret = _do_fastboot("flash", part, img_path)
    if ret != 0:
        RUYI.log.F(_m("flashing-partition-failed").format(part=part))
    return ret


#def _flash_ram(img_path: str) -> int:
def _flash_ram(img_path):
    return _do_fastboot("-S", "0", "flash", "ram", img_path)


#def _reboot_and_wait(wait_secs: float) -> int:
def _reboot_and_wait(wait_secs):
    ret = _do_fastboot("reboot")
    if ret != 0:
        RUYI.log.F(_m("reboot-failed"))
        RUYI.log.W(_m("recheck"))
        return ret

    RUYI.log.I(_m("waiting-for-device").format(wait_secs=wait_secs))
    RUYI.sleep(wait_secs)
    return 0


#def _pretend_a210_coreboot(img_paths: PartitionMapDecl, _: PartitionMapDecl) -> list[str]:
def _pretend_a210_coreboot(img_paths, blkdev_paths):
    ret = []

    if "ram_bootstrap" in img_paths:
        ret.extend([
            _m("pretend-flash-to-ram").format(img_path=img_paths["ram_bootstrap"]),
            _m("pretend-reboot"),
        ])

    ret.extend([
        _m("pretend-flash-to-ram").format(img_path=img_paths["ram_coreboot"]),
        _m("pretend-reboot"),
    ])

    msg_flash = _m("pretend-flash-to-partition")
    ret.extend([
        msg_flash.format(img_path=img_paths["emmc0boot0"], part="emmc0boot0"),
        msg_flash.format(img_path=img_paths["emmc0"], part="emmc0"),
    ])

    ret.append(_m("resuming-boot"))

    return ret


#def _flash_a210_coreboot(img_paths: PartitionMapDecl, _: PartitionMapDecl) -> int:
def _flash_a210_coreboot(img_paths, blkdev_paths):
    # Perform the equivalent of the following commands, as documented in the
    # firmware bundle:
    #
    # fastboot -S 0 flash ram "$board/ram/$board-bootstrap-rvbl.bin"
    # fastboot reboot
    # fastboot -S 0 flash ram "$board/ram/$board-coreboot-ram-rvbl.bin"
    # fastboot reboot
    # fastboot -S 0 flash emmc0boot0 "$board/emmc/$board-coreboot-boot0.bin"
    # fastboot flash emmc0 system.img
    #
    # The bootstrap stage is optional, and can be skipped on boards that
    # already run a usable EDK2 firmware.
    wait_secs = 5.0

    if "ram_bootstrap" in img_paths:
        RUYI.log.I(_m("flashing-bootstrap-ram"))
        ret = _flash_ram(img_paths["ram_bootstrap"])
        if ret != 0:
            RUYI.log.F(_m("flashing-bootstrap-ram-failed"))
            RUYI.log.W(_m("recheck"))
            return ret

        RUYI.log.I(_m("rebooting-to-bootstrap"))
        ret = _reboot_and_wait(wait_secs)
        if ret != 0:
            return ret

    RUYI.log.I(_m("flashing-coreboot-ram"))
    ret = _flash_ram(img_paths["ram_coreboot"])
    if ret != 0:
        RUYI.log.F(_m("flashing-coreboot-ram-failed"))
        RUYI.log.W(_m("recheck"))
        return ret

    RUYI.log.I(_m("rebooting-to-coreboot"))
    ret = _reboot_and_wait(wait_secs)
    if ret != 0:
        return ret

    # The RAM boot leaves the device in its EDK2 setup UI, where a fastboot
    # interface has to be selected manually.  Wait for the user to do so
    # before starting to talk to fastboot, otherwise the fastboot client may
    # attach to the pre-boot interface and lose it on re-enumeration.
    if not RUYI.cli_ask_for_yesno_confirmation(_m("prompt-enter-fastboot")):
        RUYI.log.W(_m("recheck"))
        return 1

    ret = _flash_partition("emmc0boot0", img_paths["emmc0boot0"], True)
    if ret != 0:
        return ret

    ret = _flash_partition("emmc0", img_paths["emmc0"], False)
    if ret != 0:
        return ret

    # This EDK2 build does not implement `fastboot reboot`; `continue` exits
    # fastboot and boots the system that has just been written.  Failing to do
    # so is not fatal, as the flashing itself already succeeded.
    RUYI.log.I(_m("resuming-boot"))
    ret = _do_fastboot("continue")
    if ret != 0:
        RUYI.log.W(_m("resuming-boot-failed"))
        RUYI.log.W(_m("recheck"))

    return 0


#
# Device Provisioning Strategy Plugin Interface
#

_a210_coreboot_v1 = {
    "priority": 10,
    "need_host_blkdevs_fn": _need_host_blkdevs_none,
    "need_cmd": ["sudo", "fastboot"],
    "pretend_fn": _pretend_a210_coreboot,
    "flash_fn": _flash_a210_coreboot,
}

PROVIDED_DEVICE_PROVISION_STRATEGIES_V1 = {
    "a210-coreboot-v1": _a210_coreboot_v1,
}
