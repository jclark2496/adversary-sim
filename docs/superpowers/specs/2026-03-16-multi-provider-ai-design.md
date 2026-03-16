# Multi-Provider AI Design Spec

## Problem

The adversary-sim and mdr-demo-lab projects are hardcoded to Ollama for AI scenario enrichment. Ollama requires local installation, model downloads (~2GB), and adds friction to the setup process. SEs should be able to choose between cloud APIs (faster, better quality, no local install) or a local model (free, private).

## Solution

Replace the Ollama-only AI path with a provider-agnostic layer that supports four providers: Anthropic Claude, OpenAI, Google Gemini, and local Ollama. Provider selection happens in two places:

1. **Terminal prompt during `make install`** — quick 1-5 choice with API key entry
2. **Settings modal in the SE Console** — change provider anytime without re-running install

## Scope

**Changes to:** adversary-sim repo and mdr-demo-lab repo (identical changes)

**Files modified:**
- `Makefile` — add AI provider prompt to install flow
- `.env.example` — add AI_PROVIDER, AI_API_KEY, AI_MODEL vars
- `docker-compose.yml` — pass new env vars to n8n
- `n8n/workflows/case_ingest.json` — replace Ollama HTTP node with provider router
- `n8n/workflows/export_enrichment.json` — same
- `n8n/workflows/settings_api.json` — NEW: settings read/write/test endpoints (separate workflow, not added to config_api.json — n8n expects one trigger per workflow)
- `nginx/html/index.html` — add settings gear icon + modal, update "Enriching" spinner text
- `nginx/html/admin.html` — update AI source labels (no longer always "ollama-enriched")
- `README.md` — update AI provider docs
- `CLAUDE.md` — update AI architecture reference

**Files NOT modified:**
- Scenario JSON schema (unchanged)
- CALDERA integration (unrelated)
- LabOps repo (no AI features)
- Existing prompts and JSON schemas sent to the LLM (identical across providers)

---

## Architecture

### Data Flow

```
.env
  AI_PROVIDER=anthropic|openai|gemini|ollama
  AI_API_KEY=sk-ant-...
  AI_MODEL=claude-sonnet-4-20250514  (optional override)
    ↓
docker-compose.yml (passes to n8n as env vars)
    ↓
n8n workflow
    ↓
[Existing] Build prompt + JSON schema
    ↓
[NEW] "Route to AI Provider" Code node
  ├─ anthropic → POST https://api.anthropic.com/v1/messages
  │   Headers: x-api-key, anthropic-version: 2023-06-01
  │   Body: { model, max_tokens: 4096, messages: [{ role: "user", content: prompt }] }
  │
  ├─ openai → POST https://api.openai.com/v1/chat/completions
  │   Headers: Authorization: Bearer $key
  │   Body: { model, messages: [{ role: "user", content: prompt }] }
  │
  ├─ gemini → POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key=$key
  │   Body: { contents: [{ parts: [{ text: prompt }] }] }
  │
  └─ ollama → POST http://host.docker.internal:11434/api/generate
      Body: { model, prompt, stream: false }
    ↓
[NEW] "Normalize Response" Code node
  Extracts text from provider-specific response format:
  ├─ anthropic → response.content[0].text
  ├─ openai    → response.choices[0].message.content
  ├─ gemini    → response.candidates[0].content.parts[0].text
  └─ ollama    → response.response
    ↓
[Existing] Parse JSON, build scenario, write to scenarios.json
```

### Key Design Decisions

**File-based config, not env vars:** AI settings are stored in `nginx/html/ai-config.json` (mounted into n8n at `/data/scenarios/ai-config.json`). Code nodes read this file at execution time via `require('fs')`. This avoids the need to restart the n8n container when settings change — the Settings modal writes the file and it takes effect immediately on the next enrichment call.

The `make install` prompt also writes to this file (in addition to `.env` for backward compat). The file is gitignored.

**Code node builds request, HTTP Request node executes it:** Instead of using `fetch()` in a Code node (which may not be available in all n8n versions), the "Route to Provider" Code node outputs the URL, headers, and body as JSON fields. A standard n8n HTTP Request node then executes the request using expression-based parameters (`={{ $json.url }}`). This is more resilient to n8n version changes.

**Gemini API key in URL:** Google's Gemini API uses `?key=` in the URL, which means the key appears in n8n execution logs. This is Google's documented approach and is acceptable for an SE demo tool. Noted as a known limitation.

---

## Environment Variables

### ai-config.json (primary — read at execution time)

Stored at `nginx/html/ai-config.json` (gitignored). Read by n8n Code nodes via `fs.readFileSync('/data/scenarios/ai-config.json')`.

```json
{
  "provider": "anthropic",
  "apiKey": "sk-ant-...",
  "model": "",
  "defaults": {
    "anthropic": "claude-sonnet-4-20250514",
    "openai": "gpt-4o",
    "gemini": "gemini-2.5-flash",
    "ollama": "llama3.2:3b"
  }
}
```

### .env (backward compat + Ollama host config)

Added to `.env.example`:

```env
# AI Provider — choose one: anthropic, openai, gemini, ollama
AI_PROVIDER=

# API Key — required for anthropic, openai, gemini (not for ollama)
AI_API_KEY=

# Model override — leave blank for defaults
AI_MODEL=
```

Added to `docker-compose.yml` n8n service environment:

```yaml
- AI_PROVIDER=${AI_PROVIDER:-}
- AI_API_KEY=${AI_API_KEY:-}
- AI_MODEL=${AI_MODEL:-}
```

The existing `OLLAMA_MODEL` and `OLLAMA_HOST` vars are kept for backward compatibility but only used when `AI_PROVIDER=ollama`.

---

## Install Flow

The `install` target prerequisite list changes from:
```makefile
install: _install-deps _check-docker _setup-ollama _env _detect-labops ...
```
to:
```makefile
install: _install-deps _check-docker _env _setup-ai _detect-labops ...
```

`_setup-ollama` is removed from the top-level chain and only called inside `_setup-ai` when the SE picks option 4.

Added to `Makefile`:

```
.PHONY: _setup-ai
_setup-ai:
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
      *) provider=none; label="Skipped"; needs_key=false ;; \
    esac; \
    # Write provider to .env \
    # Platform-aware sed (macOS vs Linux) \
    if [ "$$(uname)" = "Darwin" ]; then \
      sed -i '' "s/^AI_PROVIDER=.*/AI_PROVIDER=$$provider/" .env; \
    else \
      sed -i "s/^AI_PROVIDER=.*/AI_PROVIDER=$$provider/" .env; \
    fi; \
    # Prompt for API key if needed \
    if [ "$$needs_key" = "true" ]; then \
      read -p "  Enter your API key: " api_key; \
      if [ "$$(uname)" = "Darwin" ]; then \
        sed -i '' "s/^AI_API_KEY=.*/AI_API_KEY=$$api_key/" .env; \
      else \
        sed -i "s/^AI_API_KEY=.*/AI_API_KEY=$$api_key/" .env; \
      fi; \
    fi; \
    # Write ai-config.json for runtime use \
    printf '{"provider":"%s","apiKey":"%s","model":""}' "$$provider" "$${api_key:-}" > nginx/html/ai-config.json; \
    echo "✅ AI provider: $$label"; \
    # If ollama, install and pull model \
    if [ "$$provider" = "ollama" ]; then \
      $(MAKE) _setup-ollama; \
    fi
```

The existing `_setup-ollama` target (install Ollama, start it, pull model) is only called when the SE picks option 4. For cloud providers, no additional install is needed.

---

## Settings Modal (UI)

### Location
Gear icon added to the SE Console header (index.html), right side next to the nav menu.

### Modal Content
- **Provider selector** — 2x2 grid of provider cards (Anthropic, OpenAI, Gemini, Ollama). Active provider highlighted with cyan border.
- **API Key field** — text input with mask. Hidden when Ollama is selected.
- **Model override** — optional text input, shows default as placeholder.
- **Test button** — fires `POST /api/settings/test` to verify the API key.
- **Status indicator** — green "Connected" or red "Failed" after test.
- **Save/Cancel** — Save fires `POST /api/settings` to persist to `.env`.

### API Endpoints (n8n webhooks)

| Endpoint | Method | Purpose |
|---|---|---|
| `GET /api/settings` | GET | Read current AI_PROVIDER, AI_MODEL from env (never returns full key — only last 4 chars) |
| `POST /api/settings` | POST | Write AI_PROVIDER, AI_API_KEY, AI_MODEL to `.env`, signal n8n to reload |
| `POST /api/settings/test` | POST | Make a minimal API call to verify the key works, return success/error |

### Settings Persistence
The `POST /api/settings` n8n webhook:
1. Receives `{ provider, apiKey, model }` from the modal
2. Builds an `ai-config.json` object
3. Writes to `/data/scenarios/ai-config.json` via `require('fs').writeFileSync()`
4. Takes effect immediately — no container restart needed

No Docker socket access, no container restart. The "Route to Provider" Code node reads `ai-config.json` at the start of every execution, so new settings apply on the next enrichment call.

### "No Provider" State
When `AI_PROVIDER` is empty or `none`:
- The "Enrich with AI" button is still visible but shows a tooltip: "Configure AI provider in Settings ⚙"
- Clicking it opens the Settings modal instead of the enrichment form
- The Submit Case form is hidden (it requires AI)

---

## n8n Workflow Changes

### Modified Workflows
Both `case_ingest.json` and `export_enrichment.json` get the same modification:

**Before (current):**
```
Build Prompt → [HTTP Request: Ollama] → Parse Response
```

**After:**
```
Build Prompt → [Code: Route to Provider] → [HTTP Request: AI Call] → [Code: Normalize Response] → Parse Response
```

### "Route to Provider" Code Node

Reads config from file, outputs request params for the downstream HTTP Request node.

```javascript
const fs = require('fs');
const prompt = $input.first().json.prompt;

// Read config — file-based (no restart needed) with env var fallback
let provider = 'ollama', apiKey = '', model = '';
try {
  const cfg = JSON.parse(fs.readFileSync('/data/scenarios/ai-config.json', 'utf-8'));
  provider = cfg.provider || 'ollama';
  apiKey = cfg.apiKey || '';
  model = cfg.model || '';
} catch(e) {
  // Fallback to env vars (backward compat)
  provider = $env.AI_PROVIDER || 'ollama';
  apiKey = $env.AI_API_KEY || '';
  model = $env.AI_MODEL || '';
}

const defaults = {
  anthropic: 'claude-sonnet-4-20250514',
  openai: 'gpt-4o',
  gemini: 'gemini-2.5-flash',
  ollama: $env.OLLAMA_MODEL || 'llama3.2:3b'
};

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
    headers = { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' };
    body = { model: useModel, messages: [{ role: 'user', content: prompt }] };
    break;
  case 'gemini':
    url = `https://generativelanguage.googleapis.com/v1beta/models/${useModel}:generateContent?key=${apiKey}`;
    headers = { 'Content-Type': 'application/json' };
    body = { contents: [{ parts: [{ text: prompt }] }] };
    break;
  default: // ollama
    url = `${$env.OLLAMA_HOST || 'http://host.docker.internal:11434'}/api/generate`;
    headers = { 'Content-Type': 'application/json' };
    body = { model: useModel, prompt, stream: false };
}

// Output request params for HTTP Request node (not executing fetch here)
return [{ json: { provider, url, headers, body: JSON.stringify(body) } }];
```

This is followed by a standard **n8n HTTP Request node** configured with expressions:
- URL: `={{ $json.url }}`
- Method: POST
- Headers: `={{ $json.headers }}`
- Body: `={{ $json.body }}`
- Timeout: 120000ms

### "Normalize Response" Code Node

```javascript
const { provider, response } = $input.first().json;
let text;

switch (provider) {
  case 'anthropic':
    text = response.content?.[0]?.text || '';
    break;
  case 'openai':
    text = response.choices?.[0]?.message?.content || '';
    break;
  case 'gemini':
    text = response.candidates?.[0]?.content?.parts?.[0]?.text || '';
    break;
  default: // ollama
    text = response.response || '';
}

return [{ json: { response: text } }];
```

The output `{ response: text }` matches what the existing downstream nodes expect (they currently read `response` from the Ollama output).

---

## UI Changes

### index.html
1. **Settings gear icon** in header (right side, before nav menu)
2. **Settings modal** with provider cards, API key input, test button, save/cancel
3. **Enrichment spinner** text: change "Enriching via Ollama AI..." to "Enriching via AI..." (provider-agnostic)
4. **No-provider guard** on Enrich button: if no provider configured, open Settings modal instead
5. **AI badge** on scenario cards: keep purple "AI" tag but change source label from "ollama-enriched" to "ai-enriched"

### admin.html
Update all `ollama-enriched` references to also match `ai-enriched`:
- Filter chip `data-val="ollama-enriched"` → match both values
- Source label map entry for `ollama-enriched` → add `ai-enriched`
- Dropdown option `value="ollama-enriched"` → add `ai-enriched` option
- "Select all AI" button filter logic → match both source values

### Full list of `ollama-enriched` string locations (codebase search required):
- `admin.html` ~line 832: filter chip
- `admin.html` ~line 968: source label map
- `admin.html` ~line 1327: dropdown option
- `admin.html` ~line 1560: select-all-AI button
- `index.html` ~line 1598: AI tag filter logic
- `index.html` ~line 1646: AI tag display
- `export_enrichment.json`: "Build Scenario Card" node hardcodes `source: 'ollama-enriched'`

All must accept both `ollama-enriched` (backward compat) and `ai-enriched` (new).

### Files to add to .gitignore
- `nginx/html/ai-config.json` — contains API keys at runtime

---

## Backward Compatibility

- **No `ai-config.json` file:** Code node falls back to env vars (`$env.AI_PROVIDER`), then defaults to `ollama`
- **No `AI_PROVIDER` env var:** Unconditionally defaults to `ollama` (regardless of whether `OLLAMA_MODEL` is set)
- **Existing `scenarios.json` entries** with `source: "ollama-enriched"` continue to display correctly with the AI badge
- **New enrichments** use `source: "ai-enriched"` with an additional `ai_provider` field (e.g., `"ai_provider": "anthropic"`)
- **UI filters** accept both `ollama-enriched` and `ai-enriched` as AI sources

---

## Verification

- [ ] `make install` shows AI provider prompt and correctly writes to `.env`
- [ ] Picking "Ollama" during install auto-installs Ollama and pulls model
- [ ] Picking "Anthropic/OpenAI/Gemini" prompts for API key and writes to `.env`
- [ ] Picking "Skip" allows install to complete, Enrich button prompts for settings
- [ ] Settings modal opens from gear icon in SE Console
- [ ] Provider selection updates the highlighted card
- [ ] Test button verifies API key and shows Connected/Failed status
- [ ] Save persists to `.env` and restarts n8n
- [ ] Enrichment works with each of the 4 providers
- [ ] Generated scenarios appear in catalog with "AI" badge
- [ ] No provider configured → Enrich button opens Settings modal
- [ ] Existing Ollama-only installs continue working (backward compatible)
- [ ] No API keys exposed in committed files
