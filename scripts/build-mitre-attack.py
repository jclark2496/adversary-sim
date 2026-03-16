#!/usr/bin/env python3
"""
build-mitre-attack.py — MDR Demo Lab
======================================
Fetches the MITRE ATT&CK Enterprise STIX dataset, extracts every
non-deprecated, non-revoked attack-pattern technique, marks which
ones are present in the lab's CALDERA ability YAML files, and
writes nginx/html/mitre-attack.json.

Output schema (flat array, sorted by T-code):
  [{
    "id":          "T1059.001",
    "name":        "Command and Scripting Interpreter: PowerShell",
    "tactic":      "execution",
    "description": "First sentence of the technique description.",
    "in_lab":      true
  }, ...]

Usage:
    python3 scripts/build-mitre-attack.py          # from repo root
    python3 build-mitre-attack.py                  # from scripts/

Requirements:
    pip install requests pyyaml
"""

import json
import os
import re
import sys
import urllib.request

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml required — run: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

# ── Paths ────────────────────────────────────────────────────────────────────

SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT    = os.path.dirname(SCRIPT_DIR)
ABILITIES_DIR = os.path.join(REPO_ROOT, "caldera-profiles", "abilities")
OUTPUT_PATH  = os.path.join(REPO_ROOT, "nginx", "html", "mitre-attack.json")

MITRE_URL = (
    "https://raw.githubusercontent.com/mitre/cti/master/"
    "enterprise-attack/enterprise-attack.json"
)

# ── Helpers ──────────────────────────────────────────────────────────────────

def first_sentence(text):
    """Return the first sentence (up to ~200 chars) from a description."""
    if not text:
        return ""
    text = text.strip().replace("\n", " ")
    # Split on ". " or ".\n" but keep the period
    m = re.search(r"\.(\s|$)", text)
    if m:
        return text[:m.start() + 1].strip()
    return text[:200].strip()


def fetch_mitre_stix():
    """Download the MITRE ATT&CK Enterprise STIX bundle."""
    print(f"  → Fetching MITRE ATT&CK Enterprise STIX data...")
    print(f"    URL: {MITRE_URL}")
    print(f"    (This is ~50 MB — may take 30–60 seconds on a slow connection)")

    req = urllib.request.Request(
        MITRE_URL,
        headers={"User-Agent": "MDR-Demo-Lab/1.0"}
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        raw = resp.read()

    bundle = json.loads(raw)
    print(f"  ✅ Fetched {len(raw) // 1024} KB, {len(bundle.get('objects', []))} STIX objects")
    return bundle


def extract_techniques(bundle):
    """
    Extract non-deprecated, non-revoked attack-pattern objects.
    Returns list of dicts: {id, name, tactic, description}.
    """
    results = []
    objects = bundle.get("objects", [])

    for obj in objects:
        if obj.get("type") != "attack-pattern":
            continue
        if obj.get("x_mitre_deprecated", False):
            continue
        if obj.get("revoked", False):
            continue

        # Extract T-code from external_references
        t_code = None
        for ref in obj.get("external_references", []):
            if ref.get("source_name") == "mitre-attack":
                ext_id = ref.get("external_id", "")
                if ext_id.startswith("T"):
                    t_code = ext_id
                    break
        if not t_code:
            continue

        # Extract primary tactic (first kill_chain_phase from mitre-attack)
        tactic = ""
        for phase in obj.get("kill_chain_phases", []):
            if phase.get("kill_chain_name") == "mitre-attack":
                tactic = phase.get("phase_name", "")
                break

        name = obj.get("name", "")
        desc = first_sentence(obj.get("description", ""))

        results.append({
            "id":          t_code,
            "name":        name,
            "tactic":      tactic,
            "description": desc,
            "in_lab":      False   # filled in next step
        })

    return results


def build_in_lab_set():
    """
    Walk caldera-profiles/abilities/ and collect every technique.attack_id.
    Returns a set of T-code strings.
    """
    in_lab = set()

    for root, _, files in os.walk(ABILITIES_DIR):
        for fname in sorted(files):
            if not fname.endswith(".yml"):
                continue
            path = os.path.join(root, fname)
            try:
                with open(path, "r") as f:
                    docs = list(yaml.safe_load_all(f))
                ability_list = docs[0] if isinstance(docs[0], list) else docs
                for ab in ability_list:
                    if not isinstance(ab, dict):
                        continue
                    tech = ab.get("technique", {})
                    if isinstance(tech, dict):
                        attack_id = tech.get("attack_id", "")
                        if attack_id:
                            in_lab.add(attack_id.strip())
            except Exception as e:
                print(f"  ⚠️  Could not parse {fname}: {e}", file=sys.stderr)

    return in_lab


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    print("\n🎯 MDR Demo Lab — MITRE ATT&CK JSON Builder")
    print("=" * 60)

    # Step 1: Build in_lab set from CALDERA YAMLs
    print("\n[1/3] Reading CALDERA ability YAML files...")
    in_lab = build_in_lab_set()
    print(f"  ✅ Found {len(in_lab)} in-lab technique IDs:")
    for t in sorted(in_lab):
        print(f"       {t}")

    # Step 2: Fetch MITRE ATT&CK data
    print("\n[2/3] Fetching MITRE ATT&CK Enterprise data...")
    try:
        bundle = fetch_mitre_stix()
    except Exception as e:
        print(f"\n  ❌ Failed to fetch MITRE data: {e}", file=sys.stderr)
        print("     Check your internet connection and try again.", file=sys.stderr)
        sys.exit(1)

    # Step 3: Extract and annotate
    print("\n[3/3] Extracting and annotating techniques...")
    techniques = extract_techniques(bundle)

    # Mark in_lab
    lab_found = 0
    for t in techniques:
        if t["id"] in in_lab:
            t["in_lab"] = True
            lab_found += 1

    # Sort by T-code (numeric sort: T1 < T2 ... T1003.001 < T1003.002)
    def sort_key(t):
        parts = t["id"].lstrip("T").split(".")
        return tuple(int(p) for p in parts)

    techniques.sort(key=sort_key)

    # Verify all in_lab IDs were matched
    matched_ids = {t["id"] for t in techniques if t["in_lab"]}
    unmatched   = in_lab - matched_ids
    if unmatched:
        print(f"\n  ⚠️  These in-lab IDs were NOT found in MITRE data: {sorted(unmatched)}")

    # Write output
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w") as f:
        json.dump(techniques, f, indent=2, ensure_ascii=False)

    size_kb = os.path.getsize(OUTPUT_PATH) // 1024
    print(f"\n  ✅ Wrote {len(techniques)} techniques → {OUTPUT_PATH} ({size_kb} KB)")
    print(f"  ✅ {lab_found} marked as in_lab")
    if unmatched:
        print(f"  ⚠️  {len(unmatched)} in-lab IDs unmatched (check YAML technique IDs)")
    else:
        print(f"  ✅ All in-lab IDs confirmed in MITRE dataset")

    print(f"\n{'=' * 60}")
    print(f"  Done. Refresh the SE Console to pick up the new data.")
    print()


if __name__ == "__main__":
    main()
