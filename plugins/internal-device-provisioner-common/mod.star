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


def need_host_blkdevs_all(x):
    return x


def need_host_blkdevs_none(x):
    return []

#
# Implementation
#

def pretend_dd(
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


#def do_dd(infile: str, outfile: str, blocksize: int = 4096) -> int:
def do_dd(infile, outfile, blocksize=4096):
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


#def pretend_fastboot(img_paths: PartitionMapDecl, _: PartitionMapDecl) -> list[str]:
def pretend_fastboot(img_paths, blkdev_paths):
    return [
        "flash [yellow]" + f + "[/] into device partition [green]" + p + "[/]"
        for p, f in img_paths.items()
    ]


#def do_fastboot(*args: str) -> int:
def do_fastboot(*args):
    argv = ["fastboot"]
    argv.extend(args)
    return call_subprocess_with_ondemand_elevation(argv)


#def do_fastboot_flash(part: str, img_path: str) -> int:
def do_fastboot_flash(part, img_path):
    RUYI.log.I(
        "flashing [yellow]" + img_path + "[/] into device partition [green]" + part + "[/]"
    )
    ret = do_fastboot("flash", part, img_path)
    if ret != 0:
        RUYI.log.F("failed to flash [green]" + part + "[/] image into device storage")
        RUYI.log.W("the device could be in an inconsistent state now, check now")
    else:
        RUYI.log.I("[green]" + part + "[/] image successfully flashed")

    return ret
