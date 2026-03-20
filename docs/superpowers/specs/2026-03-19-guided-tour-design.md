# Guided Tour Design Spec

**Goal:** Add a polished, Driver.js-powered guided tour to all 6 pages of the adversary-sim SE Console (and mdr-demo-lab monolith), covering every major feature with per-page help always available.

**Architecture:** One new `tour.js` file defines all steps for all pages. Each HTML page imports it and calls `initTour('page-name')`. Driver.js handles spotlight/overlay rendering, themed with CSS to match the existing dark/cyan aesthetic. Mode detection reads `ai-config.json` to conditionally include LabOps-specific steps.

**Tech Stack:** Driver.js v1 (CDN), vanilla JS, CSS custom properties, localStorage

---

## Repos Affected

- `adversary-sim/nginx/html/` — primary implementation
- `mdr-demo-lab/nginx/html/` — identical copy; same element IDs and class names confirmed (both repos share identical page structure and nav). Only difference: monolith always shows the Lab Manager URL step in Settings (not conditional — it is always present in the monolith).

---

## Files

| File | Change |
|---|---|
| `nginx/html/tour.js` | **New** — all tour logic, step definitions, Driver.js init |
| `nginx/html/shared.css` | **Modify** — Driver.js theme override + `?` button styles |
| `nginx/html/index.html` | **Modify** — Driver.js CDN, tour.js import, `initTour()`, `?` nav button, `Start Tour` nav item |
| `nginx/html/console.html` | **Modify** — same |
| `nginx/html/admin.html` | **Modify** — same |
| `nginx/html/tools.html` | **Modify** — same |
| `nginx/html/settings.html` | **Modify** — same |
| `nginx/html/architecture.html` | **Modify** — same; add `id` attributes to three section headings (see Step Definitions below) |

---

## Tour Types

### 1. Getting Started Tour (cross-page)
- Auto-launches on first visit to `index.html` (800ms delay after DOM settles)
- Auto-launch fires only if `advsim_tour_done` is absent from localStorage
- Dismissible at any step via Skip button or Escape key — sets `advsim_tour_done = "1"` immediately on dismiss
- Re-launchable anytime via **"Start Tour"** text link in the nav on every page
  - Clicking "Start Tour" on any page: sets `advsim_tour_page = "index"`, clears `advsim_tour_done`, then navigates to `index.html` via `window.location.href = '/index.html'` where the tour auto-launches
- Covers all 6 pages sequentially with prompt-based navigation (SE clicks the cross-page prompt button to navigate — no auto-redirect by the tour itself)
- On each page after index, a "Continue Tour?" banner appears if `advsim_tour_page` matches that page

### 2. Per-Page Help (single-page)
- Triggered by `?` button always visible in the header on every page
- Runs only that page's spotlight steps — no cross-page prompts, no localStorage changes
- Available anytime, unlimited re-runs

---

## localStorage Keys

| Key | Value | Purpose |
|---|---|---|
| `advsim_tour_done` | `"1"` | Getting started tour completed or dismissed. Prevents auto-launch on revisit. |
| `advsim_tour_page` | page name e.g. `"console"` | Set when SE clicks a cross-page prompt. Triggers "Continue Tour?" banner on that page. Cleared after the banner is actioned or times out. |

**Banner timeout behaviour:** If the "Continue Tour?" banner auto-dismisses after 8 seconds without action, `advsim_tour_page` is cleared from localStorage (preventing the banner from reappearing on refresh). The SE can still restart the full tour via "Start Tour" in the nav.

---

## Mode Detection

`tour.js` fetches `/ai-config.json` on init (same pattern as the rest of the app):

- On success: if `labopsUrl` is non-empty → **labops or monolith mode** → include Lab Manager URL step in Settings tour; use "two-repo setup" text in Architecture intro
- On success: if `labopsUrl` is empty or absent → **standalone mode** → skip Lab Manager step; use "all-in-one" text in Architecture intro
- **On fetch failure (404, network error, malformed JSON):** default to standalone mode — skip Lab Manager step, no error thrown

For `mdr-demo-lab`: the monolith always includes the Lab Manager step regardless of `labopsUrl` (monolith always has LabOps built in). Achieved by passing `{ forceLabops: true }` option to `initTour()` in each monolith page.

---

## Visual Design

**Driver.js CDN** (loaded in `<head>` of all 6 pages):
```html
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/driver.js@1/dist/driver.css"/>
<script src="https://cdn.jsdelivr.net/npm/driver.js@1/dist/driver.iife.js"></script>
```
`tour.js` loaded just before `</body>` on all 6 pages.

**Driver.js theme** (applied via CSS overrides in `shared.css` on `.driver-popover` and children):

```css
.driver-popover {
  background: #111827;
  border: 1px solid rgba(0, 229, 255, 0.4);
  box-shadow: 0 0 24px rgba(0, 229, 255, 0.15);
  border-radius: 10px;
  padding: 16px;
  max-width: 280px;
}
.driver-popover-title {
  color: #00e5ff;
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
  letter-spacing: 1.5px;
  text-transform: uppercase;
  margin-bottom: 8px;
}
.driver-popover-description {
  color: #e2e8f0;
  font-size: 13px;
  line-height: 1.6;
}
.driver-popover-progress-text {
  color: #64748b;
  font-size: 10px;
}
.driver-popover-next-btn {
  background: transparent;
  border: 1px solid #00e5ff;
  color: #00e5ff;
  border-radius: 4px;
  padding: 4px 12px;
  font-size: 11px;
}
.driver-popover-prev-btn,
.driver-popover-close-btn {
  color: #64748b;
  background: transparent;
  border: none;
  font-size: 11px;
}
.driver-overlay { background: rgba(0, 0, 0, 0.75); }
```

**Spotlight ring** (applied via Driver.js `stagePadding` and CSS on `.driver-highlighted-element`):
```css
.driver-highlighted-element {
  border: 2px solid rgba(0, 229, 255, 0.6) !important;
  box-shadow: 0 0 0 4px rgba(0, 229, 255, 0.12), 0 0 20px rgba(0, 229, 255, 0.2) !important;
  border-radius: 6px !important;
}
```

**Intro cards** (chapter openers per page):
- Use Driver.js popover with `element: 'body'` (centers the popover, no spotlight)
- Title in Orbitron font (via inline `popoverClass` override)
- Single "Let's go →" button (hide prev, hide progress text, relabel next)

**`?` help button** (added to header on all 6 pages):
- Small circle: `width: 28px; height: 28px; border-radius: 50%; border: 1px solid rgba(0,229,255,0.4); color: #00e5ff; background: transparent; cursor: pointer; font-size: 13px`
- Placement per page:
  - `index.html`, `console.html`, `settings.html`, `architecture.html`: appended inside `#hdr-controls` before `#nav-wrap`
  - `admin.html`: appended inside `.shared-hdr-right` before `#nav-wrap` (no `#hdr-controls` exists on this page)
  - `tools.html`: appended inside `.hdr-right` before the existing DONE button
- Tooltip on hover (CSS `title` attribute): `"Page help"`

**"Start Tour" nav link** (added to `#nav-dd` dropdown on all 6 pages, and `.hdr-right` on tools.html):
- `<button class="nav-it">▶ Start Tour</button>`
- On click: `window.location.href = '/index.html?tour=1'` (tour.js detects `?tour=1` param and launches immediately, bypassing the `advsim_tour_done` check)

**"Continue Tour?" banner:**
- `position: fixed; top: 0; left: 0; right: 0; z-index: 10000; height: 36px`
- Background: `rgba(0, 229, 255, 0.08); border-bottom: 1px solid rgba(0,229,255,0.2)`
- Text: `"Getting Started Tour: continuing on [Page Name]"` with `[Continue]` and `[Dismiss]` buttons
- Auto-dismisses after 8 seconds (clears `advsim_tour_page`)
- When clicked Continue: clears banner, launches that page's tour steps from step 1 (skipping intro card)

---

## Step Definitions

### SE Console — `index.html`

Steps target static HTML elements. `#sl` is JS-rendered — tour.js waits for it using a `MutationObserver` or short `setTimeout(500)` before starting.

| Step | Selector | Tooltip Title | Tooltip Body |
|---|---|---|---|
| Intro | `body` (centered) | Welcome to the SE Console | Your launchpad for running live attack simulations. Let's walk through the key controls. |
| 1 | `#nav-btn` | Navigation | Use the Menu to move between pages: Scenario Studio, Red Tools, Architecture, and Settings. |
| 2 | `#qi` | Search Scenarios | Type to filter scenarios by name, tactic, or technique. Scenarios are grouped by product below. |
| 3 | `#sl` | Scenario Library | Scenarios are grouped by Sophos product — Endpoint, NDR, Firewall. Click any row to load its details. Star it to save as a favourite. |
| 4 | `#rp` | Scenario Details | The right panel shows expected Sophos detections, MITRE technique mapping, and talking points for the selected scenario. |
| 5 | `#tgt` | Victim IP | Enter the IP address of your Windows victim VM here. |
| 6 | `#saved-targets` | Saved Targets | Save IPs with labels and click to auto-fill. Persists across sessions — great for reusing between demos. |
| 7 | `#pngb` | Confirm Connection | Click Check to ping the victim. Before launching, confirm your victim VM's sandcat agent has checked in — it connects automatically on VM boot. |
| 8 | `#lbtn` | Launch Simulation | Starts the CALDERA operation on your victim. The Attack Console opens automatically. |
| End | — | — | Cross-page prompt: "Next up: Attack Console →" (sets `advsim_tour_page = "console"`) |

### Attack Console — `console.html`

| Step | Selector | Tooltip Title | Tooltip Body |
|---|---|---|---|
| Intro | `body` | Watch the Attack Unfold | Live CALDERA feed on the left. Live RDP session to your victim on the right. |
| 1 | `#feed` (or equivalent left panel selector) | Live Attack Feed | Each row is a MITRE ATT&CK technique executing on your victim in real time. |
| 2 | first `.feed-row` or `.link-row` if present | Ability Detail | Click any row to expand it and see the exact command that ran on the victim. |
| 3 | `#op-status` or equivalent status indicator | Operation Status | Shows whether the operation is running, complete, or stopped. Updates every 3 seconds. |
| 4 | `#rdp-frame` or `#guac-panel` (RDP iframe container) | Live Victim Desktop | Watch the attack happen on the victim in real time. Narrate what you see to the customer. |
| 5 | `#rdp-frame` or `#guac-panel` | Sophos XDR Pivot | When the attack completes, open Sophos XDR or Sophos Central to show the customer their real detections side-by-side. |
| End | — | — | Cross-page prompt: "Next up: Scenario Studio →" (sets `advsim_tour_page = "admin"`) |

> **Note for implementer:** Read `console.html` to confirm exact IDs for the feed panel, operation status indicator, and RDP panel before wiring steps 1–4.

### Scenario Studio — `admin.html`

`onHighlightStarted` callbacks used to ensure panels are visible before spotlighting:
- Step 2 (AI form): call `openCreate('ai')` if `#create-ai` is hidden
- Step 4 (Design form): call `openCreate('design')` if `#create-design` is hidden

| Step | Selector | Tooltip Title | Tooltip Body |
|---|---|---|---|
| Intro | `body` | Build Your Own Scenarios | Two creation paths: AI-powered from plain English, or manual step-by-step design. |
| 1 | `#create-cards` | Create a Scenario | Choose your creation path: AI Generate builds a scenario from plain English. Design Scenario gives you full manual control. |
| 2 | `#create-ai` → `#ai-desc` | AI Generate | Describe an attack in plain English. The AI builds a complete scenario with MITRE mapping, CALDERA abilities, and talking points. |
| 3 | `#ai-submit` | Submit Case | Click Generate to send to the AI. It maps techniques, selects CALDERA abilities, and adds talking points automatically. |
| 4 | `#create-design` → `#design-tech-chips` | Manual Design | Prefer full control? Pick MITRE techniques directly, write your own detections and talking points. |
| 5 | `#scenario-list` | Your Scenarios | All scenarios live here — including AI-generated ones pending your review. |
| 6 | first `.approve-btn` or `.edit-btn` in `#scenario-list` (or `#editd` if no scenarios exist fallback to `#scenario-list`) | Approve & Edit | Review AI-generated scenarios before they appear in the SE Console. Edit any field or delete if not needed. |
| End | — | — | Cross-page prompt: "Next up: Red Tools →" (sets `advsim_tour_page = "tools"`) |

> **Note for implementer:** For step 3 (Enrich with AI), the enrich form is in `index.html` (`#enrich-card`), not in `admin.html`. Enrich is triggered from the SE Console Tools dropdown. This is out of scope for the Scenario Studio page tour — the enrich step is removed from this page's steps.

### Red Tools — `tools.html`

| Step | Selector | Tooltip Title | Tooltip Body |
|---|---|---|---|
| Intro | `body` | Manual Red Team Access | Browser-based terminal access to your red team containers for manual techniques beyond CALDERA. |
| 1 | `#tab-kali` | Kali Linux | Opens a full Kali Linux terminal in your browser via Guacamole. Run any tool or script manually. |
| 2 | `#tab-atomic` | Atomic Red Team | Switch to the Atomic Red Team container to run Atomic tests directly via SSH. |
| End | — | — | Cross-page prompt: "Next up: Settings →" (sets `advsim_tour_page = "settings"`) |

### Settings — `settings.html`

| Step | Selector | Tooltip Title | Tooltip Body |
|---|---|---|---|
| Intro | `body` | Configure the Platform | Set your AI provider for scenario generation and (if using LabOps) connect to the Lab Manager. |
| 1 | AI provider selector element | AI Provider | Choose Anthropic, OpenAI, Gemini, or local Ollama for scenario generation and enrichment. |
| 2 | API key input element | API Key | Enter your API key here. It's stored locally in ai-config.json and never leaves your machine. |
| 3 *(labops/monolith only)* | Lab Manager URL input | Lab Manager | Enter your LabOps URL to enable VM management directly from the SE Console nav. |
| End | — | — | Cross-page prompt: "Next up: Architecture →" (sets `advsim_tour_page = "architecture"`) |

> **Note for implementer:** Read `settings.html` to confirm exact selectors for the AI provider selector and API key input before wiring steps 1–2.

### Architecture — `architecture.html`

Three `id` attributes must be added to `architecture.html` as part of this implementation (they don't currently exist):
- `id="arch-platform"` on the `<h2>` with text "Platform Architecture" (line ~471)
- `id="arch-services"` on the `<h2>` with text "Services & Ports" (line ~538)
- `id="arch-scenarios"` on the `<h2>` with text "Scenario Library" (line ~646)

| Step | Selector | Tooltip Title | Tooltip Body |
|---|---|---|---|
| Intro | `body` | How It All Connects | A reference map of every service running on your Mac Mini and how they talk to each other. Great for troubleshooting. |
| 1 | `#arch-platform` | Platform Stack | Every Docker container, its IP address, port, and role. The full picture of what's running. |
| 2 | `#arch-services` | Service Reference | Quick lookup for ports, container names, and credentials. Bookmark this page. |
| 3 | `#arch-scenarios` | Scenario Catalog | Full library of all 24 built-in scenarios with MITRE mappings and CALDERA adversary IDs. |
| End | — | — | Tour complete card: "You're ready to run live attack simulations. Head back to the SE Console to launch your first." Sets `advsim_tour_done = "1"`. |

---

## Commit Strategy

All commits on a feature branch `feat/guided-tour`. Branch merged to main when all 6 pages are wired and tested.

1. `feat: add tour.js with Driver.js step definitions for all 6 pages`
2. `feat: theme Driver.js and add tour nav buttons in shared.css`
3. `feat: wire initTour() into all 6 HTML pages, add id attrs to architecture.html`
4. `feat: port guided tour to mdr-demo-lab`
