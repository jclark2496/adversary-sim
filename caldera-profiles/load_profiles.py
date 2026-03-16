#!/usr/bin/env python3
"""
CALDERA Profile Loader — MDR Demo Lab
======================================
Loads all SCN-001, SCN-002, SCN-003 ability YAML files and adversary profiles
into CALDERA via the REST API.

Usage:
    python3 load_profiles.py

Requirements:
    pip install requests pyyaml

Assumes CALDERA is running at http://localhost:8888
API key is MDRLABRED (set in caldera/conf/local.yml)
"""

import json
import os
import sys
import uuid
import requests
import yaml

# ── Config ──────────────────────────────────────────────────────────────────
CALDERA_URL  = "http://localhost:8888"
API_KEY      = "MDRLABRED"
HEADERS      = {
    "KEY": API_KEY,
    "Content-Type": "application/json"
}

SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
ABILITIES_DIR = os.path.join(SCRIPT_DIR, "abilities")
ADVERSARIES_DIR = os.path.join(SCRIPT_DIR, "adversaries")

# ── Helpers ──────────────────────────────────────────────────────────────────
def banner(msg):
    print(f"\n{'='*60}")
    print(f"  {msg}")
    print(f"{'='*60}")

def ok(msg):   print(f"  ✅  {msg}")
def warn(msg): print(f"  ⚠️   {msg}")
def err(msg):  print(f"  ❌  {msg}")
def info(msg): print(f"  →   {msg}")


def check_caldera_alive():
    banner("Checking CALDERA connectivity")
    try:
        r = requests.get(f"{CALDERA_URL}/api/v2/health", headers=HEADERS, timeout=5)
        if r.status_code == 200:
            ok(f"CALDERA is reachable at {CALDERA_URL}")
            return True
        else:
            err(f"CALDERA returned HTTP {r.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        err(f"Cannot reach CALDERA at {CALDERA_URL}")
        err("Make sure the stack is running: cd ~/Documents/SE\\ Demo\\ Lab/mdr-demo-lab && docker-compose up -d")
        return False


def load_ability_from_yaml(yaml_path):
    """
    Reads a CALDERA ability YAML file and returns a dict formatted
    for the /api/v2/abilities POST endpoint.
    """
    with open(yaml_path, "r") as f:
        docs = yaml.safe_load_all(f)
        abilities = list(docs)

    # YAML files can be a list under a single doc or a list of docs
    if isinstance(abilities[0], list):
        ability_list = abilities[0]
    else:
        ability_list = abilities

    results = []
    for ab in ability_list:
        if not isinstance(ab, dict):
            continue

        # Build executors list for the API payload
        executors = []
        platforms = ab.get("platforms", {})
        for platform_name, platform_data in platforms.items():
            for executor_name, executor_data in platform_data.items():
                executor_map = {
                    "psh": "psh",
                    "sh":  "sh",
                    "cmd": "cmd"
                }
                exec_payload = {
                    "name":    executor_map.get(executor_name, executor_name),
                    "platform": platform_name,
                    "command": executor_data.get("command", "").strip(),
                    "cleanup": [executor_data["cleanup"].strip()] if executor_data.get("cleanup", "").strip() else []
                }
                executors.append(exec_payload)

        technique = ab.get("technique", {})
        api_payload = {
            "ability_id":  ab.get("id", str(uuid.uuid4())),
            "name":        ab.get("name", "Unnamed Ability"),
            "description": ab.get("description", "").strip(),
            "tactic":      ab.get("tactic", ""),
            "technique_id":   technique.get("attack_id", ""),
            "technique_name": technique.get("name", ""),
            "executors":   executors,
            "tags":        ab.get("tags", [])
        }
        results.append(api_payload)

    return results


def push_ability(ability_payload):
    """POST a single ability to CALDERA. Returns True on success."""
    ability_id   = ability_payload["ability_id"]
    ability_name = ability_payload["name"]

    # Check if ability already exists — use PUT to update if so
    check = requests.get(
        f"{CALDERA_URL}/api/v2/abilities/{ability_id}",
        headers=HEADERS
    )

    if check.status_code == 200:
        info(f"Ability exists — updating: {ability_name}")
        r = requests.put(
            f"{CALDERA_URL}/api/v2/abilities/{ability_id}",
            headers=HEADERS,
            json=ability_payload
        )
    else:
        info(f"Creating new ability: {ability_name}")
        r = requests.post(
            f"{CALDERA_URL}/api/v2/abilities",
            headers=HEADERS,
            json=ability_payload
        )

    if r.status_code in (200, 201):
        ok(f"[{ability_payload['technique_id']}] {ability_name}")
        return True
    else:
        err(f"Failed to push ability: {ability_name}")
        err(f"  HTTP {r.status_code}: {r.text[:200]}")
        return False


def push_adversary(adversary_path):
    """Load and POST/PUT a single adversary JSON file to CALDERA."""
    with open(adversary_path, "r") as f:
        adv = json.load(f)

    adversary_id   = adv.get("adversary_id")
    adversary_name = adv.get("name")

    # Map to CALDERA API structure
    api_payload = {
        "adversary_id":    adversary_id,
        "name":            adversary_name,
        "description":     adv.get("description", ""),
        "atomic_ordering": adv.get("atomic_ordering", []),
        "tags":            adv.get("tags", [])
    }

    # Check if adversary already exists
    check = requests.get(
        f"{CALDERA_URL}/api/v2/adversaries/{adversary_id}",
        headers=HEADERS
    )

    if check.status_code == 200:
        info(f"Adversary exists — updating: {adversary_name}")
        r = requests.put(
            f"{CALDERA_URL}/api/v2/adversaries/{adversary_id}",
            headers=HEADERS,
            json=api_payload
        )
    else:
        info(f"Creating new adversary: {adversary_name}")
        r = requests.post(
            f"{CALDERA_URL}/api/v2/adversaries",
            headers=HEADERS,
            json=api_payload
        )

    if r.status_code in (200, 201):
        ok(f"Adversary loaded: {adversary_name}")
        return True
    else:
        err(f"Failed to push adversary: {adversary_name}")
        err(f"  HTTP {r.status_code}: {r.text[:200]}")
        return False


def load_all_abilities():
    banner("Loading Ability YAML Files")
    success = 0
    failed  = 0

    for root, dirs, files in os.walk(ABILITIES_DIR):
        for filename in sorted(files):
            if not filename.endswith(".yml"):
                continue
            yaml_path = os.path.join(root, filename)
            print(f"\n  📄 {os.path.relpath(yaml_path, SCRIPT_DIR)}")
            try:
                abilities = load_ability_from_yaml(yaml_path)
                for ab in abilities:
                    if push_ability(ab):
                        success += 1
                    else:
                        failed += 1
            except Exception as e:
                err(f"Error parsing {filename}: {e}")
                failed += 1

    print(f"\n  Abilities: {success} loaded, {failed} failed")
    return failed == 0


def load_all_adversaries():
    banner("Loading Adversary Profiles")
    success = 0
    failed  = 0

    for filename in sorted(os.listdir(ADVERSARIES_DIR)):
        if not filename.endswith(".json"):
            continue
        json_path = os.path.join(ADVERSARIES_DIR, filename)
        print(f"\n  📄 {filename}")
        try:
            if push_adversary(json_path):
                success += 1
            else:
                failed += 1
        except Exception as e:
            err(f"Error loading {filename}: {e}")
            failed += 1

    print(f"\n  Adversaries: {success} loaded, {failed} failed")
    return failed == 0


def verify_load():
    banner("Verifying Profiles in CALDERA")

    expected_abilities = [
        "scn001-a1-check-privs",
        "scn001-a2-lsass-dump-comsvcs",
        "scn001-a3-mimikatz-sekurlsa",
        "scn002-a1-system-discovery",
        "scn002-a2-network-discovery",
        "scn002-a3-process-discovery",
        "scn002-a4-user-enumeration",
        "scn003-a1-payload-execution",
        "scn003-a2-scheduled-task-persistence",
        "scn003-a3-registry-persistence",
        # SCN-005: Pass the Hash
        "scn005-a1-enumerate-shares",
        "scn005-a2-extract-ntlm-hash",
        "scn005-a3-pth-authentication",
        # SCN-006: PowerShell & AMSI Bypass
        "scn006-a1-powershell-enumeration",
        "scn006-a2-amsi-bypass-attempt",
        "scn006-a3-payload-download-exec",
        # SCN-008: Ransomware Pre-Deployment
        "scn008-a1-disable-defenses",
        "scn008-a2-delete-shadow-copies",
        "scn008-a3-stage-ransom-note",
        "scn008-a4-impact-report"
    ]

    expected_adversaries = [
        "scn001-credential-dumping",
        "scn002-discovery-chain",
        "scn003-phishing-persistence",
        "scn005-pass-the-hash",
        "scn006-powershell-amsi-bypass",
        "scn008-ransomware-simulation"
    ]

    ability_ok = 0
    for ab_id in expected_abilities:
        r = requests.get(f"{CALDERA_URL}/api/v2/abilities/{ab_id}", headers=HEADERS)
        if r.status_code == 200:
            ok(f"Ability verified: {ab_id}")
            ability_ok += 1
        else:
            err(f"Ability NOT FOUND: {ab_id}")

    adv_ok = 0
    for adv_id in expected_adversaries:
        r = requests.get(f"{CALDERA_URL}/api/v2/adversaries/{adv_id}", headers=HEADERS)
        if r.status_code == 200:
            ok(f"Adversary verified: {adv_id}")
            adv_ok += 1
        else:
            err(f"Adversary NOT FOUND: {adv_id}")

    print(f"\n  ✅ {ability_ok}/{len(expected_abilities)} abilities confirmed")
    print(f"  ✅ {adv_ok}/{len(expected_adversaries)} adversaries confirmed")
    print(f"\n  🔗 Open CALDERA → Campaigns → Adversaries to see your profiles:")
    print(f"     {CALDERA_URL}")


# ── Main ─────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("\n🎯 MDR Demo Lab — CALDERA Profile Loader")
    print("   Scenarios: SCN-001 | SCN-002 | SCN-003")

    if not check_caldera_alive():
        sys.exit(1)

    abilities_ok  = load_all_abilities()
    adversaries_ok = load_all_adversaries()

    verify_load()

    if abilities_ok and adversaries_ok:
        banner("✅  All profiles loaded successfully")
        print("  Next steps:")
        print("  1. Open CALDERA at http://localhost:8888 (red / admin)")
        print("  2. Go to Campaigns → Adversaries")
        print("  3. Confirm all 6 adversaries appear: SCN-001/002/003/005/006/008")
        print("  4. When Windows VM is ready: deploy sandcat agent and run SCN-002 first (safest)")
        print()
    else:
        banner("⚠️  Some profiles failed to load — check errors above")
        sys.exit(1)
