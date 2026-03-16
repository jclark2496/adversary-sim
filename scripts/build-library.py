#!/usr/bin/env python3
"""
build-library.py — MDR Demo Lab
=================================
Reads all adversary JSON and ability YAML files from caldera-profiles/
and writes nginx/html/caldera-library.json.

This file is:
  1. Injected as context into Ollama prompts at runtime (via n8n Code node)
  2. A useful SE/admin reference for what the lab can actually run

Usage:
    python3 scripts/build-library.py    # from repo root
    python3 build-library.py            # from scripts/

Requirements:
    pip install pyyaml
"""

import json
import os
import sys
from datetime import datetime, timezone

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml required — run: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

# ── Paths ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR    = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT     = os.path.dirname(SCRIPT_DIR)
ADVERSARIES_DIR = os.path.join(REPO_ROOT, "caldera-profiles", "adversaries")
ABILITIES_DIR   = os.path.join(REPO_ROOT, "caldera-profiles", "abilities")
OUTPUT_PATH   = os.path.join(REPO_ROOT, "nginx", "html", "caldera-library.json")

# ── Loaders ───────────────────────────────────────────────────────────────────

def load_abilities():
    """Walk abilities/ and return a list of ability dicts + a lookup by ability_id."""
    abilities = []
    for root, _, files in os.walk(ABILITIES_DIR):
        for fname in sorted(files):
            if not fname.endswith(".yml"):
                continue
            path = os.path.join(root, fname)
            try:
                with open(path) as f:
                    docs = list(yaml.safe_load_all(f))
                ab_list = docs[0] if isinstance(docs[0], list) else docs
                for ab in ab_list:
                    if not isinstance(ab, dict):
                        continue
                    tech     = ab.get("technique", {}) or {}
                    platforms = ab.get("platforms", {}) or {}
                    platform  = list(platforms.keys())[0] if platforms else "windows"
                    executors = list(list(platforms.values())[0].keys()) if platforms and list(platforms.values()) else []
                    executor  = executors[0] if executors else "psh"
                    desc      = (ab.get("description") or "").strip()
                    abilities.append({
                        "ability_id":     ab.get("id", ""),
                        "name":           (ab.get("name") or "").strip(),
                        "tactic":         ab.get("tactic", ""),
                        "technique_id":   tech.get("attack_id", ""),
                        "technique_name": tech.get("name", ""),
                        "platform":       platform,
                        "executor":       executor,
                        "description":    desc[:200]
                    })
            except Exception as e:
                print(f"  ⚠️  Could not parse {fname}: {e}", file=sys.stderr)
    return abilities


def load_adversaries(abilities_by_id):
    """Read adversary JSON files and enrich with technique list from abilities."""
    adversaries = []
    for fname in sorted(os.listdir(ADVERSARIES_DIR)):
        if not fname.endswith(".json"):
            continue
        path = os.path.join(ADVERSARIES_DIR, fname)
        try:
            with open(path) as f:
                adv = json.load(f)

            ability_ids = adv.get("atomic_ordering", [])

            # Derive technique list from referenced abilities (deduplicated, ordered)
            seen = set()
            techniques = []
            for aid in ability_ids:
                if aid in abilities_by_id:
                    t = abilities_by_id[aid].get("technique_id", "")
                    if t and t not in seen:
                        seen.add(t)
                        techniques.append(t)

            # Audience from tags
            tags = adv.get("tags", [])
            audience = "executive" if "executive" in tags else "technical"

            # Derive canonical scenario_id from adversary_id (scn001-... → SCN-001)
            adv_id = adv.get("adversary_id", "")
            scenario_id = ""
            if adv_id.startswith("scn"):
                num = adv_id[3:6]       # e.g. "001" from "scn001-credential-dumping"
                scenario_id = f"SCN-{num}"

            adversaries.append({
                "adversary_id": adv_id,
                "name":         adv.get("name", ""),
                "description":  (adv.get("description") or "").strip()[:300],
                "techniques":   techniques,
                "abilities":    ability_ids,
                "audience":     audience,
                "scenario_id":  scenario_id,
                "tags":         tags
            })
        except Exception as e:
            print(f"  ⚠️  Could not parse {fname}: {e}", file=sys.stderr)
    return adversaries


def build_technique_map(adversaries):
    """Return {T-code: [adversary_id, ...]} mapping, sorted by T-code."""
    tech_map = {}
    for adv in adversaries:
        for t in adv["techniques"]:
            tech_map.setdefault(t, [])
            if adv["adversary_id"] not in tech_map[t]:
                tech_map[t].append(adv["adversary_id"])
    return dict(sorted(tech_map.items()))


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("\n🎯 MDR Demo Lab — CALDERA Library Builder")
    print("=" * 50)

    print("\n[1/3] Loading ability YAML files...")
    abilities = load_abilities()
    abilities_by_id = {a["ability_id"]: a for a in abilities}
    print(f"  ✅ {len(abilities)} abilities loaded")

    print("\n[2/3] Loading adversary profiles...")
    adversaries = load_adversaries(abilities_by_id)
    print(f"  ✅ {len(adversaries)} adversaries loaded:")
    for adv in adversaries:
        print(f"       {adv['adversary_id']} — techniques: {', '.join(adv['techniques'])}")

    print("\n[3/3] Building technique → adversary map...")
    tech_map = build_technique_map(adversaries)
    print(f"  ✅ {len(tech_map)} unique techniques mapped")

    output = {
        "generated_at":              datetime.now(timezone.utc).isoformat(),
        "adversaries":               adversaries,
        "abilities":                 abilities,
        "technique_to_adversary_map": tech_map
    }

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w") as f:
        json.dump(output, f, indent=2)

    size_kb = os.path.getsize(OUTPUT_PATH) // 1024
    print(f"\n  ✅ Written → {OUTPUT_PATH} ({size_kb} KB)")
    print(f"     Adversaries : {len(adversaries)}")
    print(f"     Abilities   : {len(abilities)}")
    print(f"     Techniques  : {len(tech_map)}")
    print()


if __name__ == "__main__":
    main()
