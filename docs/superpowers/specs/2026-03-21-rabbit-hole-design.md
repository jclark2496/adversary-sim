# The Rabbit Hole — Beta Lab & Feature Flags Design

## Goal

Give SEs a discoverable-but-hidden "lab" page where they can activate experimental features and see what's coming next. The mechanic rewards curiosity and signals that the platform is alive and evolving.

## Architecture

Three interlocking pieces:
1. **Easter egg trigger** — a dim rabbit icon in the SE Console header that links to the lab
2. **`lab.html`** — a standalone terminal-aesthetic page where SEs toggle features and see the roadmap
3. **Feature flags in `localStorage`** — toggle state persists across sessions; `index.html` reads flags on load to show/hide beta nav buttons

No new backend required. Stage Dive uses the existing `/api/scenario-build` endpoint.

---

## Part 1: Easter Egg Trigger

**Location:** `index.html` header — inside the existing `#hdr-controls` div, immediately after the `#nav-btn` hamburger button. It is the last element in `#hdr-controls`, flush to the right edge.

**Markup:**
```html
<a class="rabbit-hole-trigger" href="/lab.html" target="_blank" title="">
  <span class="rh-rabbit">🐇</span>
  <span class="rh-ver">v2.1</span>
</a>
```
No `title` attribute — no tooltip on hover.

**Hover:** Both the rabbit and `v2.1` transition together to neon pink/purple. The rabbit uses a CSS filter chain. The text uses a direct `color` transition. No glow, no drop-shadow — clean color shift only.

**Styling:**
```css
.rabbit-hole-trigger {
  display: flex;
  align-items: center;
  gap: 4px;
  text-decoration: none;
  margin-left: 8px;
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
.rabbit-hole-trigger:hover .rh-ver {
  color: #d940f5;
}
```

---

## Part 2: `lab.html` — The Rabbit Hole

### Visual Identity

Deliberately distinct from the main platform. No `shared.css` import, no platform nav, no header chrome.

| Property | Value |
|---|---|
| Background | `#080808` |
| Terminal color | `#00ff41` (Matrix green) |
| Dim/secondary | `#005c15` |
| Font | `'Courier New', monospace` throughout |
| Effect | CSS scanline overlay: `repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,0,0,0.07) 2px, rgba(0,0,0,0.07) 4px)` on a `::after` pseudo-element covering the full page |
| Page title | `<title>rabbit hole</title>` |

### Boot Sequence

Three lines appear on page load using `setTimeout`:

- Line 1 (`$ ./rabbit-hole --enter`) appears at **0ms** (immediately)
- Line 2 (`> Beta features unlocked.`) appears at **400ms**
- Line 3 (blinking cursor `_`) appears at **700ms**

Each line is a `<div class="tl">`. The cursor is `<span class="cursor">_</span>` with this CSS:

```css
.cursor {
  display: inline-block;
  animation: blink 1s step-end infinite;
}
@keyframes blink {
  50% { opacity: 0; }
}
```

The cursor blinks continuously for the duration of the page visit. It stays visible in the boot section — it does not follow the user as they scroll.

After all three lines appear, the feature section fades in below (CSS `opacity: 0 → 1` transition over 300ms).

### Layout

Single centered column, `max-width: 640px`, `margin: 0 auto`, `padding: 60px 24px 80px`. After the boot sequence, two sections separated by a dim rule (`border-top: 1px solid #005c15`).

### Section 1 — BETA

Heading: `BETA` in bright green (`#00ff41`), small caps, monospace, `font-size: 11px`, `letter-spacing: 0.2em`.

Two feature cards, each containing:
- **Name** — `font-size: 14px`, bright green
- **Description** — `font-size: 12px`, dim green (`#005c15`)
- **Toggle** — see Toggle Styling below
- A dim horizontal rule below each card

#### Toggle Styling

Custom CSS toggle. Not a native `<input type="checkbox">`. Structure:

```html
<button class="rh-toggle" data-key="rh_booth_duty" aria-pressed="false">
  <span class="rh-toggle-track">
    <span class="rh-toggle-dot"></span>
  </span>
  <span class="rh-toggle-label">OFF</span>
</button>
```

- Track: `width: 36px; height: 18px; border: 1px solid #005c15; border-radius: 9px; background: transparent`
- Dot: `width: 12px; height: 12px; border-radius: 50%; background: #005c15; position: absolute; top: 2px; left: 2px; transition: left 0.2s ease, background 0.2s ease`
- Label: `font-size: 11px; color: #005c15; margin-left: 8px; min-width: 24px`

**ON state** (when `aria-pressed="true"`):
- Track border-color: `#00ff41`
- Dot: `left: 20px; background: #00ff41`
- Label text: `ON`, color: `#00ff41`

Toggle click handler: reads `data-key`, flips the stored value in `localStorage`, updates `aria-pressed` and visual state. No page reload.

**Default state:** Both toggles default to OFF. On page load, read `localStorage.getItem(key)`. If value is `"on"`, render as ON. Any other value (including `null`) renders as OFF.

### Feature Card 1 — Booth Duty

```
Booth Duty
Run the full attack demo without any live infrastructure.
Built for trade shows and conferences.
[toggle]
```

`localStorage` key: `rh_booth_duty`

### Feature Card 2 — Stage Dive

```
Stage Dive
Describe an attack in plain English. AI builds the full scenario. You run the demo.
[toggle]
```

`localStorage` key: `rh_stage_dive`

### Section 2 — ON THE HORIZON

Heading: `ON THE HORIZON` in same style as `BETA` heading.

Three roadmap cards. Each has:
- **Name** — bright green, `font-size: 14px`
- **Description** — dim green, `font-size: 12px`
- **Badge** — `coming soon` in `font-size: 10px`, `color: #003a0d`, `border: 1px solid #003a0d`, `border-radius: 3px`, `padding: 1px 6px`

No toggles, no interactivity.

**Card 1 — Kali + Atomic Integration**
> Activate Kali Linux and Atomic Red Team within the SE Console for manual attack techniques beyond automated scenarios.

**Card 2 — Customer Mode**
> Hide SE-facing UI elements for a clean, distraction-free view during live demos with customers.

**Card 3 — AI Debrief**
> Auto-generate a post-demo attack summary — MITRE map, detections triggered, and customer-ready talking points.

### Back Link

At very bottom of page: `← back to console` as an `<a href="/index.html">`. `font-size: 11px`, `color: #005c15`, no underline. Hover: `color: #00ff41`.

---

## Part 3: Feature Flag Integration in `index.html`

On page load, `index.html` reads both `localStorage` keys and applies the following:

```javascript
const boothDuty = localStorage.getItem('rh_booth_duty') === 'on';
const stageDive = localStorage.getItem('rh_stage_dive') === 'on';
```

`null` (key not yet set) is treated as `"off"`. No explicit default-writing needed.

### Booth Duty flag (`rh_booth_duty`)

The existing Demo Mode `<button>` in the main nav (currently: `onclick="window.open('/demo.html','_blank')"`) is **hidden by default** (`display: none`).

- **OFF:** Button remains `display: none`
- **ON:** Button is shown (`display: ''`). Its label changes from `Demo Mode` to `Booth Duty`. Border/color styling changes from cyan (`rgba(0,237,255,...)`) to dim purple (`rgba(180,60,255,0.3)` border, `color: #c060f0`) to signal beta status

Same treatment applied to the matching item in the hamburger `nav-dd` dropdown.

### Stage Dive flag (`rh_stage_dive`)

A `Stage Dive` button is present in the `index.html` markup but **hidden by default** (`display: none`). It sits in the main nav next to the Booth Duty button.

- **OFF:** `display: none`
- **ON:** `display: ''`. Styled with dim purple border and color (same as Booth Duty beta styling). `onclick` opens the Stage Dive overlay.

### Stage Dive Overlay

Clicking the Stage Dive nav button injects (or reveals) a full-screen overlay element:

```html
<div id="stage-dive-overlay">
  <button id="sd-close">✕ close</button>
  <div id="sd-terminal">
    <!-- boot line -->
    <div class="sd-line dim">$ stage-dive --init</div>
    <!-- input area -->
    <div class="sd-prompt">
      <textarea id="sd-input" placeholder="Describe the attack..."></textarea>
      <button id="sd-submit">Build Scenario →</button>
    </div>
    <!-- output area, hidden until submit -->
    <div id="sd-output" style="display:none"></div>
  </div>
</div>
```

**Overlay styling** *(as implemented — optimized for stage/projector use):*
- `position: fixed; inset: 0; z-index: 1000`
- Background: `linear-gradient(150deg, #0c2d5c 0%, #1a4a8a 100%)` (bright blue gradient — high visibility on projectors)
- No scanline overlay (removed for stage clarity)
- Display: `flex; align-items: center; justify-content: center` — content card is vertically and horizontally centered
- Fade in: `opacity: 0 → 1` over `250ms`

**Content card (`#sd-terminal`):**
- `width: 92%; max-width: 960px; padding: 60px 72px`
- `border: 2px solid #f0f5ff; border-radius: 12px`
- `box-shadow: 0 0 80px rgba(240,245,255,0.08), 0 24px 64px rgba(0,0,0,0.4)`

**Text color:** `#f0f5ff` (bright off-white) throughout — maximum legibility on blue background for live stage use.

**Close button (`#sd-close`):**
- `position: absolute; top: 24px; right: 28px`
- `font-size: 14px; font-family: monospace; color: rgba(240,245,255,0.5); background: none; border: none; cursor: pointer`
- Hover: `color: #f0f5ff`

**Textarea (`#sd-input`):**
- `width: 100%; min-height: 160px`
- `font-family: 'Courier New', monospace; font-size: 19px; color: #f0f5ff`
- `background: rgba(255,255,255,0.06); border: 1px solid rgba(240,245,255,0.45); border-radius: 8px; padding: 18px 20px`
- `resize: vertical`
- Placeholder color: `rgba(240,245,255,0.35)`
- Focus: `border-color: #f0f5ff; outline: none; background: rgba(255,255,255,0.09)`

**Submit button (`#sd-submit`):**
- `margin-top: 20px`
- `font-family: 'Courier New', monospace; font-size: 17px`
- `color: #f0f5ff; background: transparent; border: 2px solid #f0f5ff; border-radius: 8px; padding: 16px 44px; cursor: pointer`
- Hover: `background: rgba(240,245,255,0.1)`
- Disabled (during loading): `opacity: 0.35; cursor: not-allowed`

#### Loading State

On submit, disable the textarea and submit button. Hide `#sd-prompt`. Show `#sd-output` with:

```
> building scenario...
> _
```

Where `_` is a blinking cursor (same CSS as `lab.html`). No spinner.

#### Success State

On successful API response, replace `#sd-output` content with:

```
> done.
>
> [scenario title]
> ──────────────────────────────────────
> MITRE
>   T1003.001 · OS Credential Dumping: LSASS Memory
>   T1059.001 · Command and Scripting Interpreter: PowerShell
>   (one line per technique from response mitre_techniques array)
>
> EXPECTED DETECTIONS
>   [CRITICAL] LSASS memory access by non-system process
>   (one line per detection, severity in brackets, from expected_detections array)
>
> ──────────────────────────────────────
> Scenario ready. Find it in the SE Console to launch.
```

Followed by a `← Close and go to scenarios` button that closes the overlay. This button is styled identically to the submit button but uses `color: #005c15; border-color: #005c15` at rest, `color: #00ff41; border-color: #00ff41` on hover.

The overlay does **not** auto-close after success. The SE reads the output, then dismisses manually.

#### Error State

On API error (non-2xx response, network failure, or timeout), replace `#sd-output` content with:

```
> error: [error message or "request failed — check your connection"]
> try again.
```

Re-enable the textarea and submit button. Hide `#sd-output`, show `#sd-prompt` again. The SE can edit their input and retry.

---

## localStorage Keys Summary

| Key | Values | Default | Effect on `index.html` |
|---|---|---|---|
| `rh_booth_duty` | `"on"` / `"off"` | `"off"` (null = off) | Shows/hides Booth Duty nav button |
| `rh_stage_dive` | `"on"` / `"off"` | `"off"` (null = off) | Shows/hides Stage Dive nav button |

---

## Files

| File | Change |
|---|---|
| `nginx/html/lab.html` | New — the rabbit hole page (standalone, no shared.css) |
| `nginx/html/index.html` | Add easter egg trigger to `#hdr-controls`; add hidden Booth Duty + Stage Dive nav buttons; add `localStorage` flag reading on load; add Stage Dive overlay markup + JS |

No other files modified. `lab.html` is fully self-contained with inline CSS and JS.

---

## Out of Scope

- Kali + Atomic Integration, Customer Mode, and AI Debrief are roadmap cards only — no implementation
- `lab.html` is not linked from any nav, sitemap, or help page — discovery only via the easter egg
- No server-side persistence — `localStorage` only
- Stage Dive does not auto-launch the CALDERA operation — it hands off to the SE Console scenario list
- No animation on the roadmap cards — static content only
