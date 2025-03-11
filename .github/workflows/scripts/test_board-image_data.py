#!/usr/bin/env python3

import argparse
import logging
import pathlib
import re
import sys

import ruyi.cli.builtin_commands as ruyi_cmd
import ruyi.config as ruyi_cfg


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(pathlib.Path(__file__).name)


# see https://github.com/ruyisdk/ruyi/blob/main/docs/naming-of-devices-and-images.md
def check_device_id(test_str: str) -> bool:
    return re.match(r"^[a-z0-9]+-[a-z0-9-]*[a-z0-9]+$", test_str) is None or \
        '--' in test_str


def check_varient_id(test_str: str) -> bool:
    return re.match(r"^[a-z0-9-.]+$", test_str) is None


# just check empty or spaces
def check_display_name(test_str: str) -> bool:
    return len(test_str) != len(test_str.strip())


def check_display_message(test_str: str) -> bool:
    return len(test_str.strip()) == 0


# documentation only combo must have links
def check_display_message_with_link(test_str: str) -> bool:
    return "Link: " not in test_str


# validate device provision data
# check all board images refered by device provision
def test_device_provision(
    pr_repo: str,
    pr_branch: str
) -> int:

    gcfg = ruyi_cfg.GlobalConfig()
    gcfg.include_prereleases = True

    # setup pr repo
    gcfg.override_repo_dir = str(pathlib.Path().resolve().joinpath("pr_repo"))
    gcfg.override_repo_url = f"https://github.com/{pr_repo}.git"
    gcfg.override_repo_branch = pr_branch
    gcfg.repo.ensure_git_repo()

    # see provision_cli.do_provision_interactive
    dpcfg = gcfg.repo.get_provisioner_config()
    if dpcfg is None:
        logger.fatal(
            "no device provisioner config found in the current Ruyi repository"
        )
        return 1

    cfg_ver = dpcfg["ruyi_provisioner_config"]
    if cfg_ver != "v1":
        logger.fatal(
            f"unknown device provisioner config version '{cfg_ver}', please check"
        )
        return 1

    logger.info(f"find device provisioner config version '{cfg_ver}'")

    # check postinst messages
    logger.info("check postinst messages")

    pmcfg = dpcfg.get("postinst_messages")
    if pmcfg is None:
        logger.fatal("no postinst messages config found")
        return 1
    for msg in pmcfg.values():
        if check_display_message(msg):
            logger.fatal(f"postinst message empty? {msg}")
            return 1

    # check image combos
    logger.info("check image combo")
    logger.info("check documentation only image combo links")

    iccfg = dpcfg.get("image_combos")
    if iccfg is None:
        logger.fatal("no image combos config found")
        return 1

    image_combos = dict()
    for ic in iccfg:
        icid = ic.get('id')
        icdname = ic.get("display_name")
        icpackages = ic.get("packages")
        icmsgid = ic.get("postinst_msgid")
        if icid is None or icdname is None:
            logger.fatal(f"image combo missing args? {str(ic)}")
            return 1
        if check_device_id(icid):
            logger.fatal(f"image combo with invalid id? {str(ic)}")
            return 1
        if check_display_name(icid):
            logger.fatal(f"image combo with invalid display name? {str(ic)}")
            return 1
        # documentation only combos
        if len(icpackages) == 0:
            if "(documentation-only)" not in icdname:
                logger.fatal(f"image combo missing packages? {str(ic)}")
                return 1
            if icmsgid is None or icmsgid not in pmcfg.keys():
                logger.fatal(f"image combo with documentatiion without postinst messages? {str(ic)}")
                return 1
            if check_display_message_with_link(pmcfg[icmsgid]):
                logger.fatal(f"image combo with documentation without link? {str(ic)}")
                return 1
        # all combos with postinst messages
        if icmsgid is not None:
            if check_device_id(icmsgid):
                logger.fatal(f"image combo with invalid postinst_msgid? {str(ic)}")
                return 1
            if icmsgid not in pmcfg.keys():
                logger.fatal(f"image combo with invalid postinst message id? {str(ic)}")
                return 1

        if icid in image_combos.keys():
            logger.fatal(f"image combo already exists? {str(ic)}")
            return 1

        image_combos.update({icid: icpackages})

    # if postinst messages all refered with image combos
    logger.info("check unreferenced postinst message")

    for ic in iccfg:
        icmsgid = ic.get("postinst_msgid")
        if icmsgid is not None and icmsgid in pmcfg.keys():
            pmcfg.pop(icmsgid)
    if len(pmcfg) > 0:
        logger.fatal(f"postinst messages not refer with any image combo? {str(pmcfg)}")
        return 1

    # check devices
    logger.info("check devices")
    
    devices = dpcfg.get("devices")
    for dev in devices:
        devid = dev.get('id')
        devname = dev.get('display_name')
        devv = dev.get('variants')
        if devid is None or devname is None or devv is None:
            logger.fatal(f"device missing info? {str(dev)}")
            return 1
        if check_device_id(devid):
            logger.fatal(f"device with invalid id? {str(dev)}")
            return 1
        if check_display_name(devname):
            logger.fatal(f"device with invalid display_name? {str(dev)}")
            return 1
        if len(devv) == 0:
            logger.fatal(f"device with empty variants list? {str(dev)}")
            return 1

        for var in devv:
            varid = var.get('id')
            varname = var.get('display_name')
            varcombos = var.get('supported_combos')
            if varid is None or varname is None or varcombos is None:
                logger.fatal(f"device variants missing info? {str(dev)}")
                return 1
            if check_varient_id(varid):
                logger.fatal(f"device variants with invalid id? {str(dev)}")
                return 1
            if check_display_name(varname):
                logger.fatal(f"device variants with strange display_name? {str(dev)}")
                return 1
            if len(varcombos) == 0:
                logger.fatal(f"device variants with empty supported_combos list? {str(dev)}")
                return 1

            for cb in varcombos:
                if cb not in image_combos.keys():
                    logger.fatal(f"device variants with non-exists combos id? {str(dev)}")
                    return 1

    # if image combos all refered with devices
    logger.info("check unreferenced image combos")

    icpkgs = dict()
    for dev in devices:
        devv = dev["variants"]
        for var in devv:
            varcombos = var["supported_combos"]
            for cb in varcombos:
                if cb not in image_combos.keys():
                    continue

                for pkg in image_combos[cb]:
                    if pkg in icpkgs.keys():
                        icpkgs[pkg].append(cb)
                    else:
                        icpkgs.update({pkg: [cb, ]})

                image_combos.pop(cb)

    if len(image_combos) > 0:
        logger.fatal(f"image combos not refer with any device? {str(image_combos)}")
        return 1

    # if board-image/* all refered with image_combos
    logger.info("check device board images")

    retv = 0
    for pkg in gcfg.repo.iter_pkgs():
        if pkg[0] != "board-image":
            continue
        if f"{pkg[0]}/{pkg[1]}" not in icpkgs.keys():
            retv += 1
            if retv > 127:
                retv = 1
            logger.fatal(f"board image {pkg[0]}/{pkg[1]} not associate with any device")
    if retv != 0:
        return retv

    return 0


if __name__ == "__main__":
    if len(sys.argv) < 3:
        logger.fatal(f"this script need two arguments but get {len(sys.argv)}")
        exit(-1)

    test_repo = sys.argv[1]
    test_branch = sys.argv[2]

    logger.info(f"testing {test_repo} branch {test_branch}")
    exit(test_device_provision(test_repo, test_branch))
else:
    logger.fatal("do not use this script like this!")
    exit(-1)

