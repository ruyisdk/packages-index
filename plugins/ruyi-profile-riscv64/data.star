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


_trivial_profiles = RUYI.load_toml("trivial-profiles.toml")["profiles"]
_trivial_profiles = {x["id"]: x for x in _trivial_profiles}
_generic_profile = _trivial_profiles["generic"]

_mcpu_map = RUYI.load_toml("flavor-specific-mcpus.toml")
_emulator_presets = RUYI.load_toml("emulator-presets.toml")


# def map_mcpu(mcpu: str, flavors: list[str]) -> str:
def map_mcpu(mcpu, flavors):
    # maybe our mcpu needs some substitution
    for fl in flavors:
        if fl not in _mcpu_map:
            continue
        if mcpu in _mcpu_map[fl]:
            return _mcpu_map[fl][mcpu]
    return mcpu


profiles = _init_profiles(
    _trivial_profiles,
    _generic_profile,
    _emulator_presets,
)
