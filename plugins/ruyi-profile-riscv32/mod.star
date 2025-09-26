RUYI = ruyi_plugin_rev(1)

load(
    "ruyi-plugin://internal-riscv-profile-data",
    _map_mcpu="map_mcpu",
    _profiles="riscv32_profiles",
)

#
# Arch Profile Plugin Interface
#

def list_all_profile_ids_v1():
    l = ["manual"]

    # NOTE: the explicit list() cast is for compatibility with both Starlark
    # and Python semantics, as Ruyi >= 0.20.0 have removed the Starlark
    # sandbox in favor of direct unsandboxed execution.
    l.extend(list(_profiles.keys()))

    return l


def list_needed_quirks_v1(profile_id):
    return _profiles[profile_id].get("needed_quirks")


def get_common_flags_v2(profile_id, toolchain_quirks):
    # Allow the user precise control if explicitly requested
    if profile_id == "manual":
        return ""

    p = _profiles[profile_id]
    args = []
    if p["mcpu"]:
        mapped_mcpu = _map_mcpu(p["mcpu"], toolchain_quirks)
        args.append("-mcpu=" + mapped_mcpu)
    if p["march"]:
        # Sometimes we want to explicitly override the march string implied
        # by the mcpu option.
        args.append("-march=" + p["march"])
    args.append("-mabi=" + p["mabi"])
    return " ".join(args)


def get_needed_emulator_pkg_flavors_v1(profile_id, emu_flavor):
    p = _profiles[profile_id]
    if not p["emulator_cfg"]:
        return []
    cfg_for_flavor = p["emulator_cfg"].get(emu_flavor)
    if not cfg_for_flavor:
        return []
    return cfg_for_flavor.get("needed_flavors", [])


def check_emulator_flavor_v1(
    profile_id,
    emu_flavor,
    emulator_pkg_flavors,  # list[str] | None
):
    req = get_needed_emulator_pkg_flavors_v1(profile_id, emu_flavor)
    if not emulator_pkg_flavors:
        return not req
    # req - emulator_pkg_flavors must be the empty set so that emulator_pkg_flavors >= req
    # the `set` type is not available in Starlark though
    # return len(req.difference(emulator_pkg_flavors)) == 0
    for elem in req:
        if elem not in emulator_pkg_flavors:
            return False
    return True


def get_env_config_for_emu_flavor_v1(
    profile_id,
    emu_flavor,
    sysroot,  # PathLike[Any] | None
):  # dict[str, str] | None
    p = _profiles[profile_id]

    result = {}

    if emu_flavor == "qemu-linux-user" and sysroot:
        result["QEMU_LD_PREFIX"] = sysroot

    if not p["emulator_cfg"]:
        return result

    cfg_for_flavor = p["emulator_cfg"].get(emu_flavor)
    if not cfg_for_flavor:
        return result

    env = cfg_for_flavor.get("env")
    if env:
        result.update(env)

    return result
