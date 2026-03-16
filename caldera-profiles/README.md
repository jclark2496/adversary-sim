# CALDERA Adversary Profiles — MDR Demo Lab
## SCN-001 | SCN-002 | SCN-003

Drop this entire `caldera-profiles/` directory into your project root at:
`~/Documents/SE Demo Lab/mdr-demo-lab/caldera-profiles/`

---

## 📁 Structure

```
caldera-profiles/
├── load_profiles.py                        ← Run this to push everything to CALDERA
├── abilities/
│   ├── credential-access/
│   │   ├── scn001-check-privileges.yml     ← T1003.001 | Verify SeDebugPrivilege
│   │   ├── scn001-lsass-dump-comsvcs.yml   ← T1003.001 | Dump LSASS via comsvcs.dll
│   │   └── scn001-mimikatz-sekurlsa.yml    ← T1003.001 | Extract creds from dump
│   ├── discovery/
│   │   ├── scn002-system-discovery.yml     ← T1082 | OS/hardware/domain enum
│   │   ├── scn002-network-discovery.yml    ← T1016 | IP/routes/connections/ARP
│   │   ├── scn002-process-discovery.yml    ← T1057 | Running procs + EDR detection
│   │   └── scn002-user-enumeration.yml     ← T1087.001 | Local users + admin group
│   ├── execution/
│   │   └── scn003-payload-execution.yml    ← T1204.002 | Post-phishing foothold sim
│   └── persistence/
│       ├── scn003-scheduled-task.yml       ← T1053.005 | Schtask disguised as Edge update
│       └── scn003-registry-runkey.yml      ← T1547.001 | HKCU Run key disguised as OneDrive
└── adversaries/
    ├── scn001-credential-dumping.json      ← Chains SCN-001 abilities in order
    ├── scn002-discovery-chain.json         ← Chains SCN-002 abilities in order
    └── scn003-phishing-persistence.json    ← Chains SCN-003 abilities in order
```

---

## 🚀 How to Load Profiles

### Prerequisites
```bash
pip3 install requests pyyaml
```

### Run the loader
```bash
cd ~/Documents/SE\ Demo\ Lab/mdr-demo-lab/caldera-profiles
python3 load_profiles.py
```

The script will:
1. Check CALDERA is reachable at `http://localhost:8888`
2. POST all 10 abilities via `/api/v2/abilities`
3. POST all 3 adversary profiles via `/api/v2/adversaries`
4. Verify each one was created successfully
5. Print a summary with next steps

### Verify in CALDERA UI
Open `http://localhost:8888` → login as `red / admin` → **Campaigns → Adversaries**
You should see:
- `SCN-001 | Credential Dumping via LSASS`
- `SCN-002 | Discovery & Enumeration Chain`
- `SCN-003 | Phishing → Payload → Persistence`

---

## 🎯 Scenario Reference

### SCN-001 | Credential Dumping via LSASS
| Step | Ability | Technique | What it Does |
|------|---------|-----------|--------------|
| 1 | check-privileges | T1003.001 | Confirms SeDebugPrivilege — required to access LSASS |
| 2 | lsass-dump-comsvcs | T1003.001 | Dumps LSASS memory to `C:\Windows\Temp\svchost.dmp` via `comsvcs.dll MiniDump` |
| 3 | mimikatz-sekurlsa | T1003.001 | Extracts NTLM hashes / plaintext creds from the dump |

**SE Demo Tip:** Run step 2 first, then show Taegis/Sophos — the LSASS access alert fires here. Step 3 is the "money shot" — hashes extracted.

**Cleanup:** Abilities include cleanup commands. Run them after the demo or CALDERA will handle it at operation end.

---

### SCN-002 | Discovery & Enumeration Chain
| Step | Ability | Technique | What it Does |
|------|---------|-----------|--------------|
| 1 | system-discovery | T1082 | OS version, hostname, domain, architecture |
| 2 | network-discovery | T1016 | IPs, routes, ARP cache, active connections |
| 3 | process-discovery | T1057 | All processes + EDR/AV detection + high-value app targeting |
| 4 | user-enumeration | T1087.001 | Local users, admin group members, active sessions |

**SE Demo Tip:** This is the safest scenario to run first when testing a new Windows VM. Low risk, generates lots of visible telemetry, great for showing detection breadth.

---

### SCN-003 | Phishing → Payload → Persistence
| Step | Ability | Technique | What it Does |
|------|---------|-----------|--------------|
| 1 | payload-execution | T1204.002 | Simulates initial foothold (narrate the phishing stage to prospect) |
| 2 | scheduled-task | T1053.005 | Creates `MicrosoftEdgeUpdateTaskMachineCore` schtask as SYSTEM |
| 3 | registry-runkey | T1547.001 | Adds `OneDriveSync` to HKCU\...\Run for logon persistence |

**SE Demo Tip:** After running steps 2 & 3, open `Task Scheduler` and `regedit` on the Windows VM to *show* the attacker artifacts before cleanup. Very visual. Then show Sophos/Taegis detected the schtask creation.

**Phase 2 Addition (when GoPhish + MailHog are up):** Swap step 1 for a live email delivery. The prospect watches the phishing email arrive in Outlook, clicks the attachment, and the agent beacons back to CALDERA. **This is the most compelling demo we can build.**

---

## ⚠️ Important Notes

- **Windows VM required for execution** — these profiles will load into CALDERA now, but won't run until a sandcat agent is deployed on a Windows target
- **All cleanup commands are included** — CALDERA runs cleanup automatically when an operation ends. You can also trigger it manually in the UI
- **SCN-001 Mimikatz:** Step 3 has a graceful fallback if `mimi.exe` isn't on disk — it prints simulated output for demo purposes. To run real Mimikatz, stage the binary at `C:\Windows\Temp\mimi.exe` on the victim before running the operation
- **CALDERA API key:** The loader uses `MDRLABRED` — matches `api_key_red` in your `local.yml`
