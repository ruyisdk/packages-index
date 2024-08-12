RUYI = ruyi_plugin_rev(1)

#
# Helpers
#

#def call_subprocess_with_ondemand_elevation(argv: list[str]) -> int:
def call_subprocess_with_ondemand_elevation(argv):
    """Executes subprocess.call, asking for sudo if the subprocess fails for
    whatever reason.
    """

    RUYI.log.D("about to spawn subprocess: argv=" + repr(argv))
    ret = RUYI.call_subprocess_argv(argv)
    if ret == 0:
        return ret

    RUYI.log.W(
        "The command failed with return code [yellow]" + str(ret) + "[/], that may or may not be caused by lack of privileges."
    )
    if not RUYI.cli_ask_for_yesno_confirmation(
        "Do you want to retry the command with [yellow]sudo[/]?"
    ):
        return ret

    RUYI.log.D("about to spawn subprocess with sudo: argv=['sudo'] + " + repr(argv))
    return RUYI.call_subprocess_argv(["sudo"] + argv)


def _need_host_blkdevs_all(x):
    return x


def _need_host_blkdevs_none(x):
    return []

#
# Implementation
#

def _pretend_dd(
    img_paths,  # PartitionMapDecl
    blkdev_paths,  # PartitionMapDecl
):  # list[str]
    result = []
    for part, img_path in img_paths.items():
        blkdev_path = blkdev_paths[part]
        result.append(
            "write [yellow]" + img_path + "[/] contents to [green]" + blkdev_path + "[/] with dd"
        )
    return result


#def _do_dd(infile: str, outfile: str, blocksize: int = 4096) -> int:
def _do_dd(infile, outfile, blocksize=4096):
    argv = [
        "dd",
        "if=" + infile,
        "of=" + outfile,
        "bs=" + str(blocksize),
    ]

    RUYI.log.I(
        "dd-ing [yellow]" + infile + "[/] to [green]" + outfile + "[/] with block size " + str(blocksize) + "..."
    )
    retcode = call_subprocess_with_ondemand_elevation(argv)
    if retcode == 0:
        RUYI.log.I("successfully flashed [green]" + outfile + "[/]")
    else:
        RUYI.log.F("failed to flash the [green]" + outfile + "[/] disk/partition")
        RUYI.log.W("the device could be in an inconsistent state now, check now")

    return retcode


#def flash_dd(img_paths: PartitionMapDecl, blkdev_paths: PartitionMapDecl) -> int:
def _flash_dd(img_paths, blkdev_paths):
    for part, img_path in img_paths.items():
        blkdev_path = blkdev_paths[part]
        ret = _do_dd(img_path, blkdev_path)
        if ret != 0:
            return ret

    return 0


#def _do_fastboot(*args: str) -> int:
def _do_fastboot(*args):
    argv = ["fastboot"]
    argv.extend(args)
    return call_subprocess_with_ondemand_elevation(argv)


#def _do_fastboot_flash(part: str, img_path: str) -> int:
def _do_fastboot_flash(part, img_path):
    RUYI.log.I(
        "flashing [yellow]" + img_path + "[/] into device partition [green]" + part + "[/]"
    )
    ret = _do_fastboot("flash", part, img_path)
    if ret != 0:
        RUYI.log.F("failed to flash [green]" + part + "[/] image into device storage")
        RUYI.log.W("the device could be in an inconsistent state now, check now")
    else:
        RUYI.log.I("[green]" + part + "[/] image successfully flashed")

    return ret


#def _pretend_lpi4a_uboot(img_paths: PartitionMapDecl, _: PartitionMapDecl) -> list[str]:
def _pretend_lpi4a_uboot(img_paths, blkdev_paths):
    p = img_paths["uboot"]
    return [
        "flash [yellow]" + p + "[/] into device RAM",
        "reboot the device",
        "flash [yellow]" + p + "[/] into device partition [green]uboot[/]",
    ]


#def _flash_lpi4a_uboot(img_paths: PartitionMapDecl, _: PartitionMapDecl) -> int:
def _flash_lpi4a_uboot(img_paths, blkdev_paths):
    # Perform the equivalent of the following commands from the Sipeed Wiki:
    #
    # sudo ./fastboot flash ram ./images/u-boot-with-spl-lpi4a-16g.bin
    # sudo ./fastboot reboot
    # sleep 1
    # sudo ./fastboot flash uboot ./images/u-boot-with-spl-lpi4a-16g.bin
    #
    # See: https://wiki.sipeed.com/hardware/en/lichee/th1520/lpi4a/4_burn_image.html
    uboot_img_path = img_paths["uboot"]

    RUYI.log.I("flashing uboot image into device RAM")
    ret = _do_fastboot("flash", "ram", uboot_img_path)
    if ret != 0:
        RUYI.log.F("failed to flash uboot image into device RAM")
        RUYI.log.W("the device state should be intact, but please re-check")
        return ret

    RUYI.log.I("rebooting device into new uboot")
    ret = _do_fastboot("reboot")
    if ret != 0:
        RUYI.log.F("failed to reboot the device")
        RUYI.log.W("the device state should be intact, but please re-check")
        return ret

    wait_secs = 1.0
    RUYI.log.I("waiting " + str(wait_secs) + "s for the device to come back online")
    RUYI.sleep(wait_secs)

    return _do_fastboot_flash("uboot", uboot_img_path)


#def _pretend_fastboot(img_paths: PartitionMapDecl, _: PartitionMapDecl) -> list[str]:
def _pretend_fastboot(img_paths, blkdev_paths):
    return [
        "flash [yellow]" + f + "[/] into device partition [green]" + p + "[/]"
        for p, f in img_paths.items()
    ]


#def _flash_fastboot(img_paths: PartitionMapDecl, _: PartitionMapDecl) -> int:
def _flash_fastboot(img_paths, blkdev_paths):
    for partition, img_path in img_paths.items():
        ret = _do_fastboot_flash(partition, img_path)
        if ret != 0:
            return ret

    return 0

#
# Device Provisioning Strategy Plugin Interface
#

_dd_v1 = {
    "priority": 0,
    "need_host_blkdevs_fn": _need_host_blkdevs_all,
    "need_cmd": ["sudo", "dd"],
    "pretend_fn": _pretend_dd,
    "flash_fn": _flash_dd,
}

_fastboot_v1 = {
    "priority": 0,
    "need_host_blkdevs_fn": _need_host_blkdevs_none,
    "need_cmd": ["sudo", "fastboot"],
    "pretend_fn": _pretend_fastboot,
    "flash_fn": _flash_fastboot,
}

_fastboot_lpi4a_uboot_v1 = {
    "priority": 10,
    "need_host_blkdevs_fn": _need_host_blkdevs_none,
    "need_cmd": ["sudo", "fastboot"],
    "pretend_fn": _pretend_lpi4a_uboot,
    "flash_fn": _flash_lpi4a_uboot,
}

PROVIDED_DEVICE_PROVISION_STRATEGIES_V1 = {
    "dd-v1": _dd_v1,
    "fastboot-v1": _fastboot_v1,
    "fastboot-v1(lpi4a-uboot)": _fastboot_lpi4a_uboot_v1,
}
