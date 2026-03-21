# The Rabbit Hole — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a discoverable easter egg in the SE Console that leads to a hidden terminal-aesthetic lab page where SEs can activate beta features (Booth Duty, Stage Dive) and see the product roadmap.

**Architecture:** Two files touched. `lab.html` is a fully standalone page (no shared.css, no platform nav) with Matrix green terminal aesthetic, animated boot sequence, toggle-based feature flags stored in localStorage, and static roadmap cards. `index.html` gets the easter egg trigger (🐇 v2.1 after the hamburger button), hidden beta nav buttons revealed by localStorage flags, and the Stage Dive full-screen overlay.

**Tech Stack:** Vanilla HTML/CSS/JS. No frameworks, no build step, no new dependencies. localStorage for persistence. Existing `/api/scenario-build` endpoint for Stage Dive.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `nginx/html/lab.html` | Create | Standalone rabbit hole page: boot sequence, feature toggles, roadmap |
| `nginx/html/index.html` | Modify | Easter egg trigger, hidden beta nav buttons, flag reading on load, Stage Dive overlay |

---

## Task 1: `lab.html` — Shell, styles, and boot sequence

**Files:**
- Create: `nginx/html/lab.html`

This task builds the page skeleton and the animated boot sequence. The feature cards section is rendered in the DOM but invisible (`opacity: 0`) — it will fade in after the boot completes. This gives us something testable before the toggle logic exists.

- [ ] **Step 1: Create `nginx/html/lab.html` with this full content**

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>rabbit hole</title>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

html, body {
  height: 100%;
  background: #080808;
  color: #00ff41;
  font-family: 'Courier New', monospace;
  font-size: 13px;
  line-height: 1.6;
}

/* Scanline overlay */
body::after {
  content: '';
  position: fixed; inset: 0; pointer-events: none; z-index: 999;
  background: repeating-linear-gradient(
    0deg,
    transparent, transparent 2px,
    rgba(0,0,0,0.07) 2px, rgba(0,0,0,0.07) 4px
  );
}

.container {
  max-width: 640px;
  margin: 0 auto;
  padding: 60px 24px 80px;
}

/* Boot sequence */
.boot { margin-bottom: 48px; }
.tl { color: #00ff41; min-height: 1.6em; }
.tl.dim { color: #005c15; }

.cursor {
  display: inline-block;
  animation: blink 1s step-end infinite;
}
@keyframes blink { 50% { opacity: 0; } }

/* Feature section — fades in after boot */
#feature-section {
  opacity: 0;
  transition: opacity 0.3s ease;
}
#feature-section.visible { opacity: 1; }

/* Section headings */
.section-rule {
  border: none;
  border-top: 1px solid #005c15;
  margin: 40px 0 28px;
}
.section-heading {
  font-size: 11px;
  letter-spacing: 0.2em;
  color: #00ff41;
  text-transform: uppercase;
  margin-bottom: 24px;
}

/* Feature cards */
.feature-card {
  margin-bottom: 28px;
  padding-bottom: 28px;
  border-bottom: 1px solid #002a0a;
}
.feature-card:last-child { border-bottom: none; }
.feature-name {
  font-size: 14px;
  color: #00ff41;
  margin-bottom: 4px;
}
.feature-desc {
  font-size: 12px;
  color: #005c15;
  margin-bottom: 14px;
  line-height: 1.5;
}

/* Toggle button */
.rh-toggle {
  display: flex;
  align-items: center;
  gap: 0;
  background: none;
  border: none;
  cursor: pointer;
  padding: 0;
  font-family: 'Courier New', monospace;
}
.rh-toggle-track {
  position: relative;
  width: 36px;
  height: 18px;
  border: 1px solid #005c15;
  border-radius: 9px;
  background: transparent;
  transition: border-color 0.2s ease;
  flex-shrink: 0;
}
.rh-toggle-dot {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #005c15;
  transition: left 0.2s ease, background 0.2s ease;
}
.rh-toggle-label {
  font-size: 11px;
  color: #005c15;
  margin-left: 10px;
  min-width: 24px;
  transition: color 0.2s ease;
}
/* ON state */
.rh-toggle[aria-pressed="true"] .rh-toggle-track { border-color: #00ff41; }
.rh-toggle[aria-pressed="true"] .rh-toggle-dot { left: 20px; background: #00ff41; }
.rh-toggle[aria-pressed="true"] .rh-toggle-label { color: #00ff41; }

/* Roadmap cards */
.roadmap-card {
  margin-bottom: 20px;
  padding-bottom: 20px;
  border-bottom: 1px solid #002a0a;
}
.roadmap-card:last-child { border-bottom: none; }
.roadmap-name {
  font-size: 14px;
  color: #00ff41;
  margin-bottom: 4px;
  display: flex;
  align-items: center;
  gap: 10px;
}
.roadmap-badge {
  font-size: 10px;
  color: #003a0d;
  border: 1px solid #003a0d;
  border-radius: 3px;
  padding: 1px 6px;
  font-weight: normal;
}
.roadmap-desc {
  font-size: 12px;
  color: #005c15;
  line-height: 1.5;
}

/* Back link */
.back-link {
  display: inline-block;
  margin-top: 48px;
  font-size: 11px;
  color: #005c15;
  text-decoration: none;
  transition: color 0.2s ease;
}
.back-link:hover { color: #00ff41; }
</style>
</head>
<body>
<div class="container">

  <!-- Boot sequence -->
  <div class="boot">
    <div class="tl dim" id="boot-1" style="display:none">$ ./rabbit-hole --enter</div>
    <div class="tl" id="boot-2" style="display:none">&gt; Beta features unlocked.</div>
    <div class="tl" id="boot-3" style="display:none">&gt; <span class="cursor">_</span></div>
  </div>

  <!-- Feature section (hidden until boot completes) -->
  <div id="feature-section">

    <hr class="section-rule">
    <div class="section-heading">Beta</div>

    <!-- Booth Duty -->
    <div class="feature-card">
      <div class="feature-name">Booth Duty</div>
      <div class="feature-desc">Run the full attack demo without any live infrastructure.<br>Built for trade shows and conferences.</div>
      <button class="rh-toggle" data-key="rh_booth_duty" aria-pressed="false">
        <span class="rh-toggle-track"><span class="rh-toggle-dot"></span></span>
        <span class="rh-toggle-label">OFF</span>
      </button>
    </div>

    <!-- Stage Dive -->
    <div class="feature-card">
      <div class="feature-name">Stage Dive</div>
      <div class="feature-desc">Describe an attack in plain English. AI builds the full scenario. You run the demo.</div>
      <button class="rh-toggle" data-key="rh_stage_dive" aria-pressed="false">
        <span class="rh-toggle-track"><span class="rh-toggle-dot"></span></span>
        <span class="rh-toggle-label">OFF</span>
      </button>
    </div>

    <hr class="section-rule">
    <div class="section-heading">On the Horizon</div>

    <!-- Roadmap cards -->
    <div class="roadmap-card">
      <div class="roadmap-name">Kali + Atomic Integration <span class="roadmap-badge">coming soon</span></div>
      <div class="roadmap-desc">Activate Kali Linux and Atomic Red Team within the SE Console for manual attack techniques beyond automated scenarios.</div>
    </div>

    <div class="roadmap-card">
      <div class="roadmap-name">Customer Mode <span class="roadmap-badge">coming soon</span></div>
      <div class="roadmap-desc">Hide SE-facing UI elements for a clean, distraction-free view during live demos with customers.</div>
    </div>

    <div class="roadmap-card">
      <div class="roadmap-name">AI Debrief <span class="roadmap-badge">coming soon</span></div>
      <div class="roadmap-desc">Auto-generate a post-demo attack summary — MITRE map, detections triggered, and customer-ready talking points.</div>
    </div>

    <a class="back-link" href="/index.html">← back to console</a>

  </div><!-- /feature-section -->
</div><!-- /container -->

<script>
// ── Boot sequence ──────────────────────────────────────────
(function() {
  var b1 = document.getElementById('boot-1');
  var b2 = document.getElementById('boot-2');
  var b3 = document.getElementById('boot-3');
  var fs = document.getElementById('feature-section');

  b1.style.display = '';
  setTimeout(function() { b2.style.display = ''; }, 400);
  setTimeout(function() {
    b3.style.display = '';
    // Fade in feature section shortly after cursor appears
    setTimeout(function() { fs.classList.add('visible'); }, 150);
  }, 700);
})();

// ── Toggle logic ───────────────────────────────────────────
function initToggles() {
  document.querySelectorAll('.rh-toggle').forEach(function(btn) {
    var key = btn.getAttribute('data-key');
    var isOn = localStorage.getItem(key) === 'on';
    setToggle(btn, isOn);

    btn.addEventListener('click', function() {
      var nowOn = btn.getAttribute('aria-pressed') !== 'true';
      localStorage.setItem(key, nowOn ? 'on' : 'off');
      setToggle(btn, nowOn);
    });
  });
}

function setToggle(btn, isOn) {
  btn.setAttribute('aria-pressed', isOn ? 'true' : 'false');
  btn.querySelector('.rh-toggle-label').textContent = isOn ? 'ON' : 'OFF';
}

initToggles();
</script>
</body>
</html>
```

- [ ] **Step 2: Open `http://localhost:8081/lab.html` in a browser and verify**

Expected:
- Black background with green scanlines visible
- Boot line 1 (`$ ./rabbit-hole --enter`) appears immediately in dim green
- Boot line 2 (`> Beta features unlocked.`) appears ~400ms later in bright green
- Blinking cursor `_` appears at ~700ms
- Feature section fades in shortly after
- Both toggles start OFF (dim state)
- Clicking a toggle switches it ON (bright green dot slides right, label says ON)
- Refreshing the page shows the toggle in its last state (localStorage persisted)
- "← back to console" link at bottom is dim, brightens on hover

- [ ] **Step 3: Commit**

```bash
git add nginx/html/lab.html
git commit -m "feat: add lab.html — rabbit hole beta page with boot sequence and feature toggles"
```

---

## Task 2: Easter egg trigger in `index.html`

**Files:**
- Modify: `nginx/html/index.html`

Add the CSS and markup for the 🐇 v2.1 trigger. Also hide the existing Demo Mode button by default and add the hidden Stage Dive button — both will be wired up in Task 3. We're hiding Demo Mode now so it doesn't appear unless the flag is on.

**Context:** The existing code at line ~1031 has:
```html
<button class="nav-tab" onclick="window.open('/demo.html','_blank')" style="background:rgba(0,237,255,0.08);border-color:rgba(0,237,255,0.3);color:#00EDFF;" title="Trade show demo mode — no live infrastructure needed">Demo Mode</button>
```
And at line ~1037:
```html
<button class="nav-btn" id="nav-btn" onclick="navToggle()">&#x2630; Menu ...
```
And at line ~1039 in the dropdown:
```html
<button class="nav-it" onclick="navToggle();window.open('/demo.html','_blank')">Demo Mode</button>
```

- [ ] **Step 1: Add the easter egg trigger CSS**

Find the `#hdr-controls` CSS block (around line 75) and add the rabbit hole trigger styles immediately after it:

```css
/* ── Easter egg trigger ── */
.rabbit-hole-trigger {
  display: flex; align-items: center; gap: 4px;
  text-decoration: none; margin-left: 8px;
}
.rh-rabbit {
  font-size: 13px;
  filter: grayscale(1) brightness(0.45);
  transition: filter 0.25s ease;
}
.rh-ver {
  font-size: 10px;
  font-family: 'JetBrains Mono', monospace;
  letter-spacing: 0.06em;
  color: rgba(160,160,175,0.28);
  transition: color 0.25s ease;
}
.rabbit-hole-trigger:hover .rh-rabbit {
  filter: grayscale(1) brightness(0.25) sepia(1) hue-rotate(250deg) saturate(30) brightness(2.8);
}
.rabbit-hole-trigger:hover .rh-ver { color: #d940f5; }
```

- [ ] **Step 2: Replace the existing Demo Mode button with Booth Duty + Stage Dive buttons**

The existing Demo Mode button is in `main-nav` at line ~1031. It becomes the Booth Duty button (renamed, hidden by default). A new Stage Dive button is added immediately after it (also hidden by default).

Change from:
```html
<button class="nav-tab" onclick="window.open('/demo.html','_blank')" style="background:rgba(0,237,255,0.08);border-color:rgba(0,237,255,0.3);color:#00EDFF;" title="Trade show demo mode — no live infrastructure needed">Demo Mode</button>
```
To:
```html
<button id="btn-booth-duty" class="nav-tab" onclick="window.open('/demo.html','_blank')" style="display:none" title="Booth Duty — trade show demo mode">Booth Duty</button>
<button id="btn-stage-dive" class="nav-tab" onclick="openStageDive()" style="display:none" title="Stage Dive — describe an attack, AI builds it">Stage Dive</button>
```

The old inline cyan styles are intentionally removed. The JS in Task 3 applies beta-purple styles at runtime when each flag is on.

- [ ] **Step 3: Update the hamburger dropdown**

Change the existing Demo Mode item in `nav-dd` from:
```html
<button class="nav-it" onclick="navToggle();window.open('/demo.html','_blank')">Demo Mode</button>
```
To:
```html
<button id="dd-booth-duty" class="nav-it" onclick="navToggle();window.open('/demo.html','_blank')" style="display:none">Booth Duty</button>
<button id="dd-stage-dive" class="nav-it" onclick="navToggle();openStageDive()" style="display:none">Stage Dive</button>
```

- [ ] **Step 4: Add the easter egg trigger markup inside `#hdr-controls`, after `#nav-btn`'s parent `.nav-wrap` div**

The `#hdr-controls` div currently ends with `</div>` closing the nav-wrap. Add the trigger as the last child of `#hdr-controls`:

```html
<a class="rabbit-hole-trigger" href="/lab.html" target="_blank">
  <span class="rh-rabbit">🐇</span>
  <span class="rh-ver">v2.1</span>
</a>
```

- [ ] **Step 5: Verify in browser**

Open `http://localhost:8081`. Expected:
- 🐇 v2.1 appears at far right of the header, after the ☰ Menu button
- Hover: rabbit and v2.1 both shift to neon pink/purple, no glow
- Clicking opens `lab.html` in a new tab
- Demo Mode and Stage Dive buttons are NOT visible in the nav (hidden)

- [ ] **Step 6: Commit**

```bash
git add nginx/html/index.html
git commit -m "feat: add rabbit hole easter egg trigger and hidden beta nav buttons"
```

---

## Task 3: Feature flag reading in `index.html`

**Files:**
- Modify: `nginx/html/index.html`

Read localStorage on page load and show/restyle the beta nav buttons accordingly.

- [ ] **Step 1: Add the feature flag JS**

Find the end of the `<script>` block in `index.html` (just before the closing `</script>` tag) and add:

```javascript
// ── Rabbit Hole feature flags ──────────────────────────────────────────────
(function applyRabbitHoleFlags() {
  var BETA_STYLE = {
    border: '1px solid rgba(180,60,255,0.3)',
    color: '#c060f0',
    background: 'rgba(180,60,255,0.06)'
  };

  function applyBetaStyle(el) {
    if (!el) return;
    el.style.border  = BETA_STYLE.border;
    el.style.color   = BETA_STYLE.color;
    el.style.background = BETA_STYLE.background;
  }

  // Booth Duty
  if (localStorage.getItem('rh_booth_duty') === 'on') {
    var btnBD = document.getElementById('btn-booth-duty');
    var ddBD  = document.getElementById('dd-booth-duty');
    if (btnBD) { btnBD.style.display = ''; applyBetaStyle(btnBD); }
    if (ddBD)  { ddBD.style.display  = ''; }
  }

  // Stage Dive
  if (localStorage.getItem('rh_stage_dive') === 'on') {
    var btnSD = document.getElementById('btn-stage-dive');
    var ddSD  = document.getElementById('dd-stage-dive');
    if (btnSD) { btnSD.style.display = ''; applyBetaStyle(btnSD); }
    if (ddSD)  { ddSD.style.display  = ''; }
  }
})();
```

- [ ] **Step 2: Test Booth Duty flag**

In browser devtools console on `http://localhost:8081`:
```javascript
localStorage.setItem('rh_booth_duty', 'on');
location.reload();
```
Expected: `Booth Duty` button appears in the main nav with dim purple border/color. Clicking it opens `demo.html` in a new tab. The dropdown also shows a `Booth Duty` item.

```javascript
localStorage.setItem('rh_booth_duty', 'off');
location.reload();
```
Expected: button is gone.

- [ ] **Step 3: Test Stage Dive flag**

```javascript
localStorage.setItem('rh_stage_dive', 'on');
location.reload();
```
Expected: `Stage Dive` button appears with dim purple styling. Clicking it calls `openStageDive()` which doesn't exist yet — a console error is fine at this stage.

- [ ] **Step 4: Test via lab.html**

Open `lab.html`, toggle Booth Duty ON, click "← back to console". The SE Console will load fresh (it's a new navigation, not a reload) — the flag is read on page load, so the button should appear immediately.

- [ ] **Step 5: Commit**

```bash
git add nginx/html/index.html
git commit -m "feat: read rabbit hole localStorage flags on SE Console load"
```

---

## Task 4: Stage Dive overlay

**Files:**
- Modify: `nginx/html/index.html`

Build the full-screen Stage Dive overlay. This is the largest task — CSS, HTML, and JS for the overlay, loading state, success state, and error state.

- [ ] **Step 1: Add Stage Dive overlay CSS**

In the `<style>` block of `index.html`, add:

```css
/* ── Stage Dive overlay ──────────────────────────────────── */
#stage-dive-overlay {
  display: none;
  position: fixed; inset: 0; z-index: 1000;
  background: #080808;
  font-family: 'Courier New', monospace;
  color: #00ff41;
  opacity: 0;
  transition: opacity 0.25s ease;
}
#stage-dive-overlay.sd-visible { display: block; }
#stage-dive-overlay.sd-faded-in { opacity: 1; }
#stage-dive-overlay::after {
  content: '';
  position: fixed; inset: 0; pointer-events: none;
  background: repeating-linear-gradient(
    0deg,
    transparent, transparent 2px,
    rgba(0,0,0,0.07) 2px, rgba(0,0,0,0.07) 4px
  );
}
#sd-close {
  position: absolute; top: 20px; right: 24px;
  font-size: 11px; font-family: 'Courier New', monospace;
  color: #005c15; background: none; border: none; cursor: pointer;
  transition: color 0.2s ease; z-index: 1;
}
#sd-close:hover { color: #00ff41; }
#sd-terminal {
  max-width: 640px; margin: 0 auto; padding: 60px 24px;
}
.sd-line { font-size: 13px; line-height: 1.8; }
.sd-line.dim { color: #005c15; }
#sd-prompt { margin-top: 24px; }
#sd-input {
  width: 100%; min-height: 120px;
  font-family: 'Courier New', monospace; font-size: 14px;
  color: #00ff41; background: transparent;
  border: 1px solid #005c15; border-radius: 4px; padding: 12px;
  resize: vertical; outline: none;
  transition: border-color 0.2s ease;
}
#sd-input::placeholder { color: #003a0d; }
#sd-input:focus { border-color: #00ff41; }
#sd-submit {
  display: block; margin-top: 12px;
  font-family: 'Courier New', monospace; font-size: 13px;
  color: #00ff41; background: transparent;
  border: 1px solid #00ff41; border-radius: 3px;
  padding: 8px 20px; cursor: pointer;
  transition: background 0.2s ease;
}
#sd-submit:hover { background: rgba(0,255,65,0.08); }
#sd-submit:disabled { opacity: 0.4; cursor: not-allowed; }
#sd-output { margin-top: 20px; display: none; }
.sd-output-line { font-size: 13px; line-height: 1.9; color: #00ff41; }
.sd-output-line.dim { color: #005c15; }
.sd-output-line.rule { color: #003a0d; }
#sd-done-btn {
  display: block; margin-top: 20px;
  font-family: 'Courier New', monospace; font-size: 13px;
  color: #005c15; background: transparent;
  border: 1px solid #005c15; border-radius: 3px;
  padding: 8px 20px; cursor: pointer;
  transition: color 0.2s ease, border-color 0.2s ease;
}
#sd-done-btn:hover { color: #00ff41; border-color: #00ff41; }
.sd-cursor {
  display: inline-block;
  animation: sd-blink 1s step-end infinite;
}
@keyframes sd-blink { 50% { opacity: 0; } }
```

- [ ] **Step 2: Add Stage Dive overlay HTML**

Add this immediately before the closing `</body>` tag in `index.html`:

```html
<!-- Stage Dive overlay -->
<div id="stage-dive-overlay">
  <button id="sd-close" onclick="closeStageDive()">✕ close</button>
  <div id="sd-terminal">
    <div class="sd-line dim">$ stage-dive --init</div>
    <div id="sd-prompt">
      <textarea id="sd-input" placeholder="Describe the attack..."></textarea>
      <button id="sd-submit" onclick="stageDiveSubmit()">Build Scenario →</button>
    </div>
    <div id="sd-output"></div>
  </div>
</div>
```

- [ ] **Step 3: Add Stage Dive JS functions**

In the `<script>` block, add before the closing `</script>`:

```javascript
// ── Stage Dive overlay ─────────────────────────────────────────────────────
function openStageDive() {
  var overlay = document.getElementById('stage-dive-overlay');
  overlay.classList.add('sd-visible');
  // Reset state
  document.getElementById('sd-prompt').style.display = '';
  document.getElementById('sd-output').style.display = 'none';
  document.getElementById('sd-output').innerHTML = '';
  document.getElementById('sd-input').value = '';
  document.getElementById('sd-input').disabled = false;
  document.getElementById('sd-submit').disabled = false;
  // Fade in
  // Small delay ensures display:block is applied before opacity transition fires
  setTimeout(function() { overlay.classList.add('sd-faded-in'); }, 10);
  document.getElementById('sd-input').focus();
}

function closeStageDive() {
  var overlay = document.getElementById('stage-dive-overlay');
  overlay.classList.remove('sd-faded-in');
  setTimeout(function() { overlay.classList.remove('sd-visible'); }, 260);
}

function stageDiveSubmit() {
  var input = document.getElementById('sd-input');
  var description = input.value.trim();
  if (!description) { input.focus(); return; }

  // Disable inputs, show loading
  input.disabled = true;
  document.getElementById('sd-submit').disabled = true;
  document.getElementById('sd-prompt').style.display = 'none';

  var output = document.getElementById('sd-output');
  output.innerHTML = '<div class="sd-output-line">&gt; building scenario...</div>' +
                     '<div class="sd-output-line">&gt; <span class="sd-cursor">_</span></div>';
  output.style.display = '';

  fetch('/api/scenario-build', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ mode: 'ai', description: description })
  })
  .then(function(res) {
    if (!res.ok) return res.text().then(function(t) { throw new Error(t || res.statusText); });
    return res.json();
  })
  .then(function(data) { stageDiveSuccess(output, data); })
  .catch(function(err) { stageDiveError(output, input, err); });
}

function stageDiveSuccess(output, data) {
  var title = data.title || data.id || 'Unnamed Scenario';
  var techniques = (data.mitre_techniques || []).map(function(t) {
    return '<div class="sd-output-line">&nbsp;&nbsp;' + t.id + ' · ' + t.name + '</div>';
  }).join('');
  var detections = (data.expected_detections || []).map(function(d) {
    var sev = (d.severity || 'info').toUpperCase();
    return '<div class="sd-output-line">&nbsp;&nbsp;[' + sev + '] ' + d.detection + '</div>';
  }).join('');

  var RULE = '<div class="sd-output-line rule">──────────────────────────────────────</div>';

  output.innerHTML =
    '<div class="sd-output-line">&gt; done.</div>' +
    '<div class="sd-output-line">&gt;</div>' +
    '<div class="sd-output-line">&gt; ' + title + '</div>' +
    RULE +
    (techniques ? '<div class="sd-output-line">&gt; MITRE</div>' + techniques + '<div class="sd-output-line">&gt;</div>' : '') +
    (detections ? '<div class="sd-output-line">&gt; EXPECTED DETECTIONS</div>' + detections + '<div class="sd-output-line">&gt;</div>' : '') +
    RULE +
    '<div class="sd-output-line">&gt; Scenario ready. Find it in the SE Console to launch.</div>' +
    '<button id="sd-done-btn" onclick="closeStageDive()">← Close and go to scenarios</button>';
}

function stageDiveError(output, input, err) {
  var msg = (err && err.message) ? err.message : 'request failed — check your connection';
  output.innerHTML =
    '<div class="sd-output-line">&gt; error: ' + msg + '</div>' +
    '<div class="sd-output-line">&gt; try again.</div>';

  // Re-enable inputs after a moment
  setTimeout(function() {
    output.style.display = 'none';
    output.innerHTML = '';
    document.getElementById('sd-prompt').style.display = '';
    input.disabled = false;
    document.getElementById('sd-submit').disabled = false;
    input.focus();
  }, 2500);
}
```

- [ ] **Step 4: Verify the overlay opens**

In browser with Stage Dive flag enabled:
- Click Stage Dive button → overlay fades in over the SE Console
- `$ stage-dive --init` line visible in dim green
- Textarea is focused, placeholder text visible
- ✕ close button top-right — click it, overlay fades out
- Empty submit does nothing (no request sent)

- [ ] **Step 5: Verify loading state**

Submit a short description. Expected:
- Inputs disabled, prompt hidden
- `> building scenario...` and blinking `_` appear

- [ ] **Step 6: Verify error state**

To force an error without touching the AI provider, temporarily change the fetch URL in the JS from `'/api/scenario-build'` to `'/api/does-not-exist'`. Submit any description. Expected: error message appears (`> error: Not Found`), then the form resets after 2.5s for retry. Restore the correct URL after testing.

- [ ] **Step 7: Verify success state (requires AI provider configured)**

Submit `"A credential dumping attack using Mimikatz on a Windows endpoint"`. Expected: loading state → success output showing scenario title, MITRE techniques, expected detections, and the `← Close and go to scenarios` button. Clicking the button closes the overlay.

- [ ] **Step 8: Commit**

```bash
git add nginx/html/index.html
git commit -m "feat: add Stage Dive full-screen overlay with AI scenario build"
```

---

## Task 5: End-to-end smoke test and cleanup

**Files:**
- Modify: `nginx/html/index.html` (minor — remove the old hamburger dropdown Demo Mode entry that's now been replaced)

A final pass to verify the whole flow works together and clean up any loose ends.

- [ ] **Step 1: Full flow test — Booth Duty**

1. Open `http://localhost:8081` → confirm no Booth Duty/Stage Dive/Demo Mode in nav
2. Click 🐇 v2.1 → lab opens in new tab
3. Toggle Booth Duty ON
4. Return to SE Console tab, reload
5. Confirm `Booth Duty` appears with purple styling
6. Click it → `demo.html` opens in new tab
7. Open hamburger menu → confirm `Booth Duty` also appears there

- [ ] **Step 2: Full flow test — Stage Dive**

1. In lab.html toggle Stage Dive ON
2. Return to SE Console, reload
3. Confirm `Stage Dive` appears with purple styling
4. Click → overlay opens
5. Type a description, submit
6. Verify loading → success (or error if AI not configured)
7. Close → overlay dismissed, SE Console visible

- [ ] **Step 3: Full flow test — toggle OFF**

1. In lab.html toggle both features OFF
2. Return to SE Console, reload
3. Confirm both buttons are gone
4. Confirm 🐇 v2.1 still visible and hovering correctly

- [ ] **Step 4: Verify lab.html back link**

On `lab.html`: click `← back to console` → lands on `http://localhost:8081/index.html`.

- [ ] **Step 5: Commit**

```bash
git add nginx/html/index.html nginx/html/lab.html
git commit -m "test: verify rabbit hole end-to-end flow"
```

(If no changes were needed, skip this commit.)
