# Multi-Provider AI Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Ollama-only AI enrichment with a provider-agnostic layer supporting Anthropic, OpenAI, Gemini, and Ollama — configurable during install and via a Settings modal.

**Architecture:** AI config stored in `ai-config.json` (read at n8n execution time, no restart needed). n8n Code node reads config and builds provider-specific HTTP request params, passed to a standard HTTP Request node. Settings modal in index.html writes config via n8n webhook endpoint.

**Tech Stack:** n8n workflows (JSON), vanilla HTML/CSS/JS, Makefile (bash), Docker Compose

**Applies to:** adversary-sim (primary) and mdr-demo-lab (identical changes). Build in adversary-sim first, then copy to mdr-demo-lab.

**Spec:** `docs/superpowers/specs/2026-03-16-multi-provider-ai-design.md`

---

## Chunk 1: Configuration Layer

### Task 1: Add ai-config.json to .gitignore and create template

**Files:**
- Modify: `adversary-sim/.gitignore`
- Create: `adversary-sim/nginx/html/ai-config.json`

- [ ] **Step 1: Add ai-config.json to .gitignore**

Add to `.gitignore` after the `.labops-mode` line:

```
nginx/html/ai-config.json
```

- [ ] **Step 2: Create default ai-config.json**

Create `nginx/html/ai-config.json`:

```json
{
  "provider": "",
  "apiKey": "",
  "model": ""
}
```

This ships as empty (no provider configured). `make install` or the Settings modal populates it.

- [ ] **Step 3: Commit**

```bash
git add .gitignore nginx/html/ai-config.json
git commit -m "feat: add ai-config.json for multi-provider AI support"
```

---

### Task 2: Update .env.example and docker-compose.yml

**Files:**
- Modify: `adversary-sim/.env.example`
- Modify: `adversary-sim/docker-compose.yml`

- [ ] **Step 1: Add AI provider vars to .env.example**

After the existing Ollama section (line 17), add:

```env
# ── AI Provider ────────────────────────────────────────────────────────
# Choose one: anthropic, openai, gemini, ollama
# Cloud providers need an API key. Ollama is free and runs locally.
AI_PROVIDER=

# API Key — required for anthropic, openai, gemini (not needed for ollama)
AI_API_KEY=

# Model override — leave blank for sensible defaults:
#   anthropic: claude-sonnet-4-20250514
#   openai: gpt-4o
#   gemini: gemini-2.5-flash
#   ollama: llama3.2:3b
AI_MODEL=
```

- [ ] **Step 2: Add env vars to docker-compose.yml n8n service**

In `docker-compose.yml`, add to the n8n service `environment:` block (after the OLLAMA lines around line 89):

```yaml
      - AI_PROVIDER=${AI_PROVIDER:-}
      - AI_API_KEY=${AI_API_KEY:-}
      - AI_MODEL=${AI_MODEL:-}
```

- [ ] **Step 3: Commit**

```bash
git add .env.example docker-compose.yml
git commit -m "feat: add AI_PROVIDER, AI_API_KEY, AI_MODEL env vars"
```

---

### Task 3: Update Makefile — replace _setup-ollama with _setup-ai

**Files:**
- Modify: `adversary-sim/Makefile`

- [ ] **Step 1: Change install target prerequisites**

Change the `install:` line from:
```makefile
install: _install-deps _check-docker _setup-ollama _env _detect-labops _generate-caldera-keys _pull-caldera _up _wait-healthy sandcat profiles mitre-update
```

To:
```makefile
install: _install-deps _check-docker _env _setup-ai _detect-labops _generate-caldera-keys _pull-caldera _up _wait-healthy sandcat profiles mitre-update
```

Note: `_setup-ollama` removed from chain, `_setup-ai` added after `_env` (needs .env to exist first).

- [ ] **Step 2: Add _setup-ai target**

Add before the `_check-docker` target:

```makefile
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
	printf '{"provider":"%s","apiKey":"%s","model":""}' "$$provider" "$$api_key" > nginx/html/ai-config.json; \
	echo "✅ AI provider: $$label"; \
	if [ "$$provider" = "ollama" ]; then \
		$(MAKE) _setup-ollama; \
	fi
```

- [ ] **Step 3: Commit**

```bash
git add Makefile
git commit -m "feat: add _setup-ai target with provider prompt during install"
```

---

## Chunk 2: n8n Workflow Changes

### Task 4: Create settings_api.json workflow

**Files:**
- Create: `adversary-sim/n8n/workflows/settings_api.json`

- [ ] **Step 1: Create settings API workflow**

Create `n8n/workflows/settings_api.json` with three webhook endpoints:

1. `GET /webhook/settings` — reads `ai-config.json`, returns provider + masked key
2. `POST /webhook/settings` — writes provider/key/model to `ai-config.json`
3. `POST /webhook/settings/test` — makes a minimal API call to verify the key works

The workflow JSON should contain:
- **Webhook: GET Settings** → **Code: Read Config** → **Respond**
- **Webhook: POST Settings** → **Code: Write Config** → **Respond**
- **Webhook: POST Test** → **Code: Build Test Request** → **HTTP Request: Test Call** → **Respond**

Write the full JSON workflow file. Key implementation details:

Read Config node:
```javascript
const fs = require('fs');
let cfg = { provider: '', apiKey: '', model: '' };
try {
  cfg = JSON.parse(fs.readFileSync('/data/scenarios/ai-config.json', 'utf-8'));
} catch(e) {}
// Mask API key — only return last 4 chars
const masked = cfg.apiKey ? '••••' + cfg.apiKey.slice(-4) : '';
return [{ json: { provider: cfg.provider, apiKeyMasked: masked, model: cfg.model } }];
```

Write Config node:
```javascript
const fs = require('fs');
const { provider, apiKey, model } = $input.first().json.body;
const cfg = { provider: provider || '', apiKey: apiKey || '', model: model || '' };
fs.writeFileSync('/data/scenarios/ai-config.json', JSON.stringify(cfg, null, 2));
return [{ json: { success: true, provider: cfg.provider } }];
```

Build Test Request node (outputs URL/headers/body for HTTP Request node):
```javascript
const fs = require('fs');
const { provider, apiKey } = $input.first().json.body;
const key = apiKey || '';
let url, headers, body;
switch (provider) {
  case 'anthropic':
    url = 'https://api.anthropic.com/v1/messages';
    headers = { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' };
    body = { model: 'claude-sonnet-4-20250514', max_tokens: 10, messages: [{ role: 'user', content: 'Hi' }] };
    break;
  case 'openai':
    url = 'https://api.openai.com/v1/chat/completions';
    headers = { 'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json' };
    body = { model: 'gpt-4o', max_tokens: 10, messages: [{ role: 'user', content: 'Hi' }] };
    break;
  case 'gemini':
    url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=' + key;
    headers = { 'Content-Type': 'application/json' };
    body = { contents: [{ parts: [{ text: 'Hi' }] }] };
    break;
  case 'ollama':
    url = ($env.OLLAMA_HOST || 'http://host.docker.internal:11434') + '/api/tags';
    headers = {}; body = null;
    return [{ json: { url, headers, body: '', method: 'GET' } }];
  default:
    throw new Error('Unknown provider: ' + provider);
}
return [{ json: { url, headers, body: JSON.stringify(body), method: 'POST' } }];
```

- [ ] **Step 2: Commit**

```bash
git add n8n/workflows/settings_api.json
git commit -m "feat: add settings_api.json workflow for AI provider CRUD"
```

---

### Task 5: Update case_ingest.json — replace Ollama node with provider router

**Files:**
- Modify: `adversary-sim/n8n/workflows/case_ingest.json`

- [ ] **Step 1: Replace the Ollama HTTP Request node**

In `case_ingest.json`, find the node named "Ollama - Generate Scenario" (HTTP Request node). Replace it with two nodes:

**Node A: "Route to AI Provider"** (Code node)
```javascript
const fs = require('fs');
const prompt = $input.first().json.prompt;

let provider = 'ollama', apiKey = '', model = '';
try {
  const cfg = JSON.parse(fs.readFileSync('/data/scenarios/ai-config.json', 'utf-8'));
  provider = cfg.provider || 'ollama';
  apiKey = cfg.apiKey || '';
  model = cfg.model || '';
} catch(e) {
  provider = $env.AI_PROVIDER || 'ollama';
  apiKey = $env.AI_API_KEY || '';
  model = $env.AI_MODEL || '';
}

const defaults = { anthropic: 'claude-sonnet-4-20250514', openai: 'gpt-4o', gemini: 'gemini-2.5-flash', ollama: $env.OLLAMA_MODEL || 'llama3.2:3b' };
const useModel = model || defaults[provider] || defaults.ollama;
let url, headers, body;

switch (provider) {
  case 'anthropic':
    url = 'https://api.anthropic.com/v1/messages';
    headers = { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' };
    body = { model: useModel, max_tokens: 4096, messages: [{ role: 'user', content: prompt }] };
    break;
  case 'openai':
    url = 'https://api.openai.com/v1/chat/completions';
    headers = { 'Authorization': 'Bearer ' + apiKey, 'Content-Type': 'application/json' };
    body = { model: useModel, messages: [{ role: 'user', content: prompt }] };
    break;
  case 'gemini':
    url = 'https://generativelanguage.googleapis.com/v1beta/models/' + useModel + ':generateContent?key=' + apiKey;
    headers = { 'Content-Type': 'application/json' };
    body = { contents: [{ parts: [{ text: prompt }] }] };
    break;
  default:
    url = ($env.OLLAMA_HOST || 'http://host.docker.internal:11434') + '/api/generate';
    headers = { 'Content-Type': 'application/json' };
    body = { model: useModel, prompt, stream: false };
}

return [{ json: { provider, url, headers, body: JSON.stringify(body) } }];
```

**Node B: "AI Call"** (HTTP Request node)
- URL: `={{ $json.url }}`
- Method: POST
- Headers: expression-based from `$json.headers`
- Body: `={{ $json.body }}`
- Timeout: 120000ms

**Node C: "Normalize Response"** (Code node)
```javascript
const provider = $('Route to AI Provider').first().json.provider;
const response = $input.first().json;
let text;
switch (provider) {
  case 'anthropic': text = response.content?.[0]?.text || ''; break;
  case 'openai': text = response.choices?.[0]?.message?.content || ''; break;
  case 'gemini': text = response.candidates?.[0]?.content?.parts?.[0]?.text || ''; break;
  default: text = response.response || '';
}
return [{ json: { response: text } }];
```

Update connections: Build Prompt → Route to Provider → AI Call → Normalize Response → existing Parse/Build nodes.

- [ ] **Step 2: Update source field in downstream nodes**

In the "Build Scenario JSON" node, change:
- `source: 'case-submission'` → keep as-is (case submissions are different from enrichments)
- Add `ai_provider: provider` field to the scenario object

- [ ] **Step 3: Commit**

```bash
git add n8n/workflows/case_ingest.json
git commit -m "feat: replace Ollama node with multi-provider router in case_ingest"
```

---

### Task 6: Update export_enrichment.json — same provider router

**Files:**
- Modify: `adversary-sim/n8n/workflows/export_enrichment.json`

- [ ] **Step 1: Apply same changes as case_ingest.json**

Replace the "Ollama - Enrich with ATT&CK" HTTP Request node with the same three-node pattern:
- Route to AI Provider (Code) → AI Call (HTTP Request) → Normalize Response (Code)

Same code as Task 5.

- [ ] **Step 2: Update source field in Build Scenario Card node**

Change `source: 'ollama-enriched'` to `source: 'ai-enriched'`.
Add `ai_provider` field from the Route to Provider node's output.

- [ ] **Step 3: Commit**

```bash
git add n8n/workflows/export_enrichment.json
git commit -m "feat: replace Ollama node with multi-provider router in export_enrichment"
```

---

## Chunk 3: UI Changes

### Task 7: Add Settings modal to index.html

**Files:**
- Modify: `adversary-sim/nginx/html/index.html`

- [ ] **Step 1: Add gear icon to header**

Find the header right section (around line 1169-1178). Add a settings gear button:

```html
<button class="settings-btn" onclick="openSettings()" title="Settings">⚙</button>
```

Add CSS for `.settings-btn` (in the `<style>` block):
```css
.settings-btn {
  font-size: 18px; background: none; border: 1px solid var(--b-dim);
  border-radius: 4px; padding: 4px 8px; cursor: pointer;
  color: var(--t-dim); transition: all .15s;
}
.settings-btn:hover { border-color: var(--b-accent); color: var(--c-cyan); }
```

- [ ] **Step 2: Add Settings modal HTML**

Add before `</body>`:

```html
<!-- Settings Modal -->
<div class="modal-overlay" id="settings-overlay" onclick="if(event.target===this)closeSettings()">
  <div class="settings-modal">
    <div class="settings-hdr">
      <span class="settings-title">⚙ SETTINGS</span>
      <button class="settings-close" onclick="closeSettings()">✕</button>
    </div>
    <div class="settings-body">
      <div class="settings-label">AI Provider</div>
      <div class="provider-grid" id="provider-grid">
        <div class="provider-card" data-provider="anthropic" onclick="selectProvider('anthropic')">
          <div class="provider-name">Anthropic</div>
          <div class="provider-sub">Claude Sonnet</div>
        </div>
        <div class="provider-card" data-provider="openai" onclick="selectProvider('openai')">
          <div class="provider-name">OpenAI</div>
          <div class="provider-sub">GPT-4o</div>
        </div>
        <div class="provider-card" data-provider="gemini" onclick="selectProvider('gemini')">
          <div class="provider-name">Google</div>
          <div class="provider-sub">Gemini Pro</div>
        </div>
        <div class="provider-card" data-provider="ollama" onclick="selectProvider('ollama')">
          <div class="provider-name">Ollama</div>
          <div class="provider-sub">Local · Free</div>
        </div>
      </div>
      <div id="apikey-section">
        <div class="settings-label">API Key</div>
        <div class="apikey-row">
          <input type="password" id="settings-apikey" class="settings-input" placeholder="Enter API key...">
          <button class="settings-test-btn" id="settings-test-btn" onclick="testProvider()">TEST</button>
        </div>
      </div>
      <div class="settings-label">Model (optional override)</div>
      <input type="text" id="settings-model" class="settings-input" placeholder="Leave blank for default">
      <div class="settings-status" id="settings-status"></div>
    </div>
    <div class="settings-footer">
      <button class="settings-cancel-btn" onclick="closeSettings()">CANCEL</button>
      <button class="settings-save-btn" id="settings-save-btn" onclick="saveSettings()">SAVE</button>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Add Settings modal CSS**

Add to the `<style>` block:

```css
.modal-overlay { display:none; position:fixed; inset:0; background:rgba(0,0,0,.6); z-index:5000; align-items:center; justify-content:center; }
.modal-overlay.open { display:flex; }
.settings-modal { background:var(--bg-card); border:1px solid var(--b-accent); border-radius:8px; width:440px; max-width:90vw; }
.settings-hdr { padding:16px 20px; border-bottom:1px solid var(--b-dim); display:flex; justify-content:space-between; align-items:center; }
.settings-title { font-family:var(--font-head); font-size:13px; font-weight:700; letter-spacing:.1em; }
.settings-close { background:none; border:none; color:var(--t-dim); font-size:16px; cursor:pointer; }
.settings-body { padding:20px; }
.settings-label { font-size:10px; color:var(--t-dim); letter-spacing:.1em; text-transform:uppercase; margin-bottom:8px; margin-top:14px; }
.settings-label:first-child { margin-top:0; }
.provider-grid { display:grid; grid-template-columns:1fr 1fr; gap:6px; }
.provider-card { background:var(--bg-surface,#0d1225); border:1px solid var(--b-dim); border-radius:4px; padding:10px; text-align:center; cursor:pointer; transition:all .15s; }
.provider-card:hover { border-color:var(--b-accent); }
.provider-card.active { background:rgba(0,237,255,.08); border-color:rgba(0,237,255,.4); }
.provider-name { font-weight:700; font-size:11px; }
.provider-card.active .provider-name { color:var(--c-cyan); }
.provider-sub { font-size:9px; color:var(--t-dim); margin-top:2px; }
.apikey-row { display:flex; gap:6px; }
.settings-input { flex:1; background:var(--bg-term,#0d1117); border:1px solid var(--b-dim); border-radius:4px; padding:8px 10px; color:var(--t-bright); font-family:var(--font-mono); font-size:11px; width:100%; box-sizing:border-box; }
.settings-input:focus { outline:none; border-color:var(--c-cyan); }
.settings-test-btn { font-family:var(--font-mono); font-size:10px; font-weight:700; letter-spacing:.06em; padding:8px 14px; background:rgba(0,237,255,.08); border:1px solid var(--b-accent); border-radius:4px; color:var(--c-cyan); cursor:pointer; }
.settings-status { margin-top:14px; padding:10px; border-radius:4px; font-size:11px; display:none; }
.settings-status.ok { display:flex; align-items:center; gap:8px; background:rgba(0,255,65,.05); border:1px solid rgba(0,255,65,.2); color:var(--c-green); }
.settings-status.err { display:flex; align-items:center; gap:8px; background:rgba(255,68,68,.05); border:1px solid var(--b-fail); color:var(--c-fail); }
.settings-footer { padding:12px 20px; border-top:1px solid var(--b-dim); display:flex; justify-content:flex-end; gap:8px; }
.settings-cancel-btn, .settings-save-btn { font-family:var(--font-mono); font-size:10px; font-weight:700; letter-spacing:.06em; padding:8px 16px; border-radius:4px; cursor:pointer; }
.settings-cancel-btn { background:transparent; border:1px solid var(--b-dim); color:var(--t-dim); }
.settings-save-btn { background:rgba(0,237,255,.12); border:1px solid var(--b-accent); color:var(--c-cyan); }
```

- [ ] **Step 4: Add Settings modal JavaScript**

Add to the `<script>` block:

```javascript
// ── Settings Modal ──────────────────────────────────────────────
let settingsProvider = '';
let settingsApiKey = '';

async function openSettings() {
  // Load current config
  try {
    const r = await fetch('/api/settings');
    if (r.ok) {
      const cfg = await r.json();
      settingsProvider = cfg.provider || '';
      document.getElementById('settings-apikey').value = cfg.apiKeyMasked || '';
      document.getElementById('settings-model').value = cfg.model || '';
    }
  } catch(e) {}
  updateProviderCards();
  document.getElementById('settings-status').className = 'settings-status';
  document.getElementById('settings-overlay').classList.add('open');
}

function closeSettings() {
  document.getElementById('settings-overlay').classList.remove('open');
}

function selectProvider(p) {
  settingsProvider = p;
  updateProviderCards();
  // Hide API key for ollama
  document.getElementById('apikey-section').style.display = p === 'ollama' ? 'none' : 'block';
}

function updateProviderCards() {
  document.querySelectorAll('.provider-card').forEach(c => {
    c.classList.toggle('active', c.dataset.provider === settingsProvider);
  });
}

async function testProvider() {
  const btn = document.getElementById('settings-test-btn');
  const status = document.getElementById('settings-status');
  btn.textContent = 'TESTING...'; btn.disabled = true;
  try {
    const r = await fetch('/api/settings/test', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        provider: settingsProvider,
        apiKey: document.getElementById('settings-apikey').value
      })
    });
    if (r.ok) {
      status.className = 'settings-status ok';
      status.innerHTML = '<span>●</span> Connected — ' + settingsProvider;
    } else {
      const err = await r.text();
      status.className = 'settings-status err';
      status.innerHTML = '<span>●</span> Failed: ' + err;
    }
  } catch(e) {
    status.className = 'settings-status err';
    status.innerHTML = '<span>●</span> Error: ' + e.message;
  }
  btn.textContent = 'TEST'; btn.disabled = false;
}

async function saveSettings() {
  try {
    const r = await fetch('/api/settings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        provider: settingsProvider,
        apiKey: document.getElementById('settings-apikey').value,
        model: document.getElementById('settings-model').value
      })
    });
    if (r.ok) {
      closeSettings();
      // Show toast if available
      if (typeof toast === 'function') toast('AI provider saved: ' + settingsProvider);
    }
  } catch(e) {
    alert('Failed to save: ' + e.message);
  }
}
```

- [ ] **Step 5: Update enrichment spinner text**

Find line ~1586: `Enriching via Ollama AI…` → change to `Enriching via AI…`

- [ ] **Step 6: Update AI tag logic**

Find line ~1598:
```javascript
const ai = s.source === 'ollama-enriched' || s.source === 'se-enrichment';
```
Change to:
```javascript
const ai = s.source === 'ollama-enriched' || s.source === 'ai-enriched' || s.source === 'se-enrichment';
```

- [ ] **Step 7: Add no-provider guard on Enrich button**

In the `encGenerate()` function (line ~2174), add at the top:

```javascript
// Check if AI provider is configured
try {
  const r = await fetch('/api/settings');
  const cfg = await r.json();
  if (!cfg.provider) { openSettings(); return; }
} catch(e) {}
```

- [ ] **Step 8: Commit**

```bash
git add nginx/html/index.html
git commit -m "feat: add Settings modal with AI provider configuration"
```

---

### Task 8: Update admin.html — AI source references

**Files:**
- Modify: `adversary-sim/nginx/html/admin.html`

- [ ] **Step 1: Update all ollama-enriched references**

Apply these changes:

Line ~832 — filter chip:
```html
<!-- Before -->
<button class="chip" data-filter="source" data-val="ollama-enriched">AI</button>
<!-- After -->
<button class="chip" data-filter="source" data-val="ai" onclick="filterAI(this)">AI</button>
```

Line ~968 — source label map, add entry:
```javascript
'ai-enriched': ['AI', 'src-ai'],
```

Line ~1327 — dropdown option, add:
```html
<option value="ai-enriched" ${s.source==='ai-enriched'?'selected':''}>AI Generated</option>
```

Line ~1560 — select all AI, update filter:
```javascript
$('sel-all-ai').addEventListener('click', () => selectWhere(s => s.source === 'ollama-enriched' || s.source === 'ai-enriched'));
```

- [ ] **Step 2: Commit**

```bash
git add nginx/html/admin.html
git commit -m "feat: update admin.html to support ai-enriched source alongside ollama-enriched"
```

---

## Chunk 4: Copy to Monolith & Finalize

### Task 9: Copy changes to mdr-demo-lab

**Files:**
- Modify: Multiple files in `/Users/fig/Documents/SE Demo Lab/mdr-demo-lab/`

- [ ] **Step 1: Copy modified files**

```bash
SRC="/Users/fig/Documents/adversary-sim"
DST="/Users/fig/Documents/SE Demo Lab/mdr-demo-lab"

# n8n workflows
cp "$SRC/n8n/workflows/case_ingest.json" "$DST/n8n/workflows/"
cp "$SRC/n8n/workflows/export_enrichment.json" "$DST/n8n/workflows/"
cp "$SRC/n8n/workflows/settings_api.json" "$DST/n8n/workflows/"

# HTML files
cp "$SRC/nginx/html/index.html" "$DST/nginx/html/"
cp "$SRC/nginx/html/admin.html" "$DST/nginx/html/"

# Config template
cp "$SRC/nginx/html/ai-config.json" "$DST/nginx/html/"
```

- [ ] **Step 2: Update mdr-demo-lab .env.example**

Add the same AI_PROVIDER, AI_API_KEY, AI_MODEL vars.

- [ ] **Step 3: Update mdr-demo-lab docker-compose.yml**

Add AI_PROVIDER, AI_API_KEY, AI_MODEL to the n8n service environment block.

- [ ] **Step 4: Update mdr-demo-lab .gitignore**

Add `nginx/html/ai-config.json`.

- [ ] **Step 5: Update mdr-demo-lab Makefile**

Add `_setup-ai` target (same as adversary-sim). Replace `_check-ollama` with `_setup-ai` in install prerequisites.

- [ ] **Step 6: Commit mdr-demo-lab**

```bash
cd "$DST"
git add -A
git commit -m "feat: add multi-provider AI support (Anthropic, OpenAI, Gemini, Ollama)

Terminal prompt during make install + Settings modal in SE Console.
AI config stored in ai-config.json for runtime flexibility.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Update docs and push

**Files:**
- Modify: `adversary-sim/README.md`
- Modify: `adversary-sim/CLAUDE.md`

- [ ] **Step 1: Update adversary-sim README**

Update the Prerequisites section to remove Ollama as a hard requirement. Add an "AI Provider" section explaining the 4 options and how to change via Settings.

- [ ] **Step 2: Update adversary-sim CLAUDE.md**

Update the architecture reference: add AI provider routing docs, settings API endpoints, ai-config.json reference.

- [ ] **Step 3: Commit and push adversary-sim**

```bash
cd /Users/fig/Documents/adversary-sim
git add -A
git commit -m "docs: update README and CLAUDE.md for multi-provider AI

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push
```

- [ ] **Step 4: Push mdr-demo-lab (if it has a remote)**

```bash
cd /Users/fig/Documents/SE\ Demo\ Lab/mdr-demo-lab
git push
```

---

## Verification Checklist

- [ ] `make install` in adversary-sim shows AI provider prompt (1-5)
- [ ] Picking option 1 (Anthropic) prompts for API key and writes to `.env` + `ai-config.json`
- [ ] Picking option 4 (Ollama) installs Ollama and pulls model
- [ ] Picking option 5 (Skip) completes install, no AI configured
- [ ] Settings gear icon visible in SE Console header
- [ ] Settings modal opens, shows 4 provider cards
- [ ] Selecting a provider highlights the card, hides API key for Ollama
- [ ] Test button verifies API key connectivity
- [ ] Save writes to `ai-config.json` (verify with `cat nginx/html/ai-config.json`)
- [ ] Enrichment works with configured provider
- [ ] Generated scenarios show "AI" badge in SE Console
- [ ] No provider configured → Enrich button opens Settings modal
- [ ] `cat ai-config.json` not in git history (`git log --all -p | grep apiKey` returns nothing)
- [ ] Same changes work in mdr-demo-lab
