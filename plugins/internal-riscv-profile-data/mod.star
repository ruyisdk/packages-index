RUYI = ruyi_plugin_rev(1)

#
# Preparation of state
#

def _init_profiles(profiles, generic, emulator_presets):
    res = {}
    for id, p in profiles.items():
        if id == "generic":
            p["emulator_cfg"] = emulator_presets.get("generic")
            res[id] = p
            continue

        p["mabi"] = p.get("mabi", generic["mabi"])
        p["march"] = p.get("march", generic["march"])
        p["mcpu"] = p.get("mcpu", generic["mcpu"])

        mcpu_for_emu = p["mcpu"] if p["mcpu"] else "generic"
        p["emulator_cfg"] = emulator_presets.get(
            mcpu_for_emu,
            emulator_presets.get("generic"),
        )

        res[id] = p

    return res


_trivial_rv32_profiles = RUYI.load_toml("trivial-riscv32-profiles.toml")["profiles"]
_trivial_rv32_profiles = {x["id"]: x for x in _trivial_rv32_profiles}
_generic_rv32_profile = _trivial_rv32_profiles["generic-rv32gc"]

_trivial_rv64_profiles = RUYI.load_toml("trivial-riscv64-profiles.toml")["profiles"]
_trivial_rv64_profiles = {x["id"]: x for x in _trivial_rv64_profiles}
_generic_rv64_profile = _trivial_rv64_profiles["generic"]

_mcpu_map = RUYI.load_toml("mcpu-quirks.toml")
_emulator_presets = RUYI.load_toml("emulator-presets.toml")


# def map_mcpu(mcpu: str, quirks: list[str]) -> str:
def map_mcpu(mcpu, quirks):
    # maybe our mcpu needs some substitution
    for q in quirks:
        if q not in _mcpu_map:
            continue
        if mcpu in _mcpu_map[q]:
            return _mcpu_map[q][mcpu]
    return mcpu


riscv32_profiles = _init_profiles(
    _trivial_rv32_profiles,
    _generic_rv32_profile,
    _emulator_presets,
)

riscv64_profiles = _init_profiles(
    _trivial_rv64_profiles,
    _generic_rv64_profile,
    _emulator_presets,
)
