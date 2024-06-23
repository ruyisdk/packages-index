RUYI = ruyi_plugin_rev(1)

#
# Preparation of state
#

def _init_profiles(profiles, generic, mcpu_map, emulator_presets):
    res = {}
    for id, p in profiles.items():
        if id == "generic":
            p["emulator_cfg"] = emulator_presets.get("generic")
            res[id] = p
            continue

        p["mabi"] = p.get("mabi", generic["mabi"])
        p["march"] = p.get("march", generic["march"])
        raw_mcpu = p.get("mcpu", generic["mcpu"])
        p["mcpu"] = raw_mcpu

        if raw_mcpu and "needed_flavors" in p:
            # maybe our mcpu needs some substitution
            for fl in p["needed_flavors"]:
                if fl not in mcpu_map:
                    continue
                if raw_mcpu not in mcpu_map[fl]:
                    continue
                p["mcpu"] = mcpu_map[fl][raw_mcpu]
                break

        mcpu_for_emu = raw_mcpu if raw_mcpu else "generic"
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

profiles = _init_profiles(
    _trivial_profiles,
    _generic_profile,
    _mcpu_map,
    _emulator_presets,
)
