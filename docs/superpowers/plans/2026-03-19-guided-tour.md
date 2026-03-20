# Guided Tour Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Driver.js-powered guided tour to all 6 pages of the adversary-sim SE Console, with auto-launch on first visit, per-page `?` help, and a cross-page Getting Started flow — then port identically to mdr-demo-lab.

**Architecture:** One new `tour.js` file holds all step definitions, mode detection (reads `/ai-config.json`), and Driver.js initialization. Each HTML page adds the Driver.js CDN, imports `tour.js`, and calls `initTour('page-name')`. A `?` button in every page header triggers per-page help. A "Start Tour" nav item re-runs the full cross-page tour. CSS overrides in `shared.css` theme Driver.js to match the dark/cyan aesthetic.

**Tech Stack:** Driver.js v1 (CDN), vanilla JS (ES5-compatible), CSS custom properties, localStorage

**Spec:** `docs/superpowers/specs/2026-03-19-guided-tour-design.md`

---

## File Map

| File | What changes |
|---|---|
| `nginx/html/tour.js` | **New** — all tour logic, step definitions, Driver.js init |
| `nginx/html/shared.css` | **Modify** — append Driver.js theme + tour UI styles |
| `nginx/html/index.html` | **Modify** — CDN links, `?` button in `#hdr-controls`, Start Tour in `#nav-dd`, `initTour('index')` before `</body>` |
| `nginx/html/console.html` | **Modify** — CDN, `?` button in `.hdr-right`, Start Tour in `#nav-dd`, `initTour('console')` |
| `nginx/html/admin.html` | **Modify** — CDN, `?` button in `.shared-hdr-right`, Start Tour in `#nav-dd`, `initTour('admin')` |
| `nginx/html/tools.html` | **Modify** — CDN, `?` button + Tour link in `.hdr-right`, `initTour('tools')` |
| `nginx/html/settings.html` | **Modify** — CDN, `?` button in `#hdr-controls`, Start Tour in `#nav-dd`, `initTour('settings')` |
| `nginx/html/architecture.html` | **Modify** — CDN, `?` button, Start Tour, add 3 IDs to section headings, `initTour('architecture')` |

---

## Codebase Context

- All pages live in `adversary-sim/nginx/html/`
- `shared.css` is imported by every page via `<link rel="stylesheet" href="shared.css">` (relative, not absolute)
- CSS variables: `--bg-deep: #03071e`, `--accent-cyan: #00e5ff`, `--fm: 'JetBrains Mono', monospace`
- Driver.js v1 IIFE global: `window.driver.js.driver(opts)` — NOT `new Driver()`
- `#hdr-controls` exists in: `index.html`, `settings.html`, `architecture.html`
- `console.html` has `<header id="hdr">` with `.hdr-right` containing `#nav-wrap` — no `#hdr-controls`
- `admin.html` uses `.shared-hdr-right` (no `#hdr-controls`)
- `tools.html` uses `#hdr` with `.hdr-left` / `.hdr-right` — no `#nav-dd` dropdown
- `#nav-dd` dropdown exists in all pages **except** `tools.html`
- `tour.js` is loaded just before `</body>` — DOM is already fully built when it runs, so `DOMContentLoaded` is already fired and must NOT be used. Wire event listeners directly.
- Docker container `advsim-nginx` must be restarted after any HTML/JS/CSS change: `docker restart advsim-nginx`
- **Git note:** repo has uncommitted changes on `main` (`Makefile`, `caldera/conf/local.yml`, `nginx/html/scenarios.json`). Run `git stash` before creating the feature branch to keep those changes off it, then `git stash pop` after branching.

---

## Task 1: Create tour.js

**Files:**
- Create: `nginx/html/tour.js`

- [ ] **Step 1: Stash uncommitted changes and create feature branch**

```bash
git stash
git checkout -b feat/guided-tour
git stash pop
```

- [ ] **Step 2: Create the file with the full tour engine**

```javascript
// nginx/html/tour.js
// Guided tour — Driver.js v1 wrapper for all 6 SE Console pages.
// Loaded by each page just before </body>. Each page calls initTour('page-name').
// DOM is already ready when this runs — never use DOMContentLoaded here.

(function () {
  'use strict';

  var DONE_KEY = 'advsim_tour_done';
  var PAGE_KEY = 'advsim_tour_page';

  var PAGE_NAMES = {
    console:      'Attack Console',
    admin:        'Scenario Studio',
    tools:        'Red Tools',
    settings:     'Settings',
    architecture: 'Architecture'
  };

  var NEXT_PAGE = {
    index:        { page: 'console',      label: 'Attack Console',  url: '/console.html' },
    console:      { page: 'admin',        label: 'Scenario Studio', url: '/admin.html' },
    admin:        { page: 'tools',        label: 'Red Tools',       url: '/tools.html' },
    tools:        { page: 'settings',     label: 'Settings',        url: '/settings.html' },
    settings:     { page: 'architecture', label: 'Architecture',    url: '/architecture.html' },
    architecture: null
  };

  // ── Step definitions ───────────────────────────────────────────────────────

  function indexSteps() {
    return [
      {
        popover: {
          title: 'WELCOME TO THE SE CONSOLE',
          description: 'Your launchpad for running live attack simulations. Let\'s walk through the key controls.',
          showButtons: ['next'],
          nextBtnText: 'Let\'s go \u2192'
        }
      },
      {
        element: '#nav-btn',
        popover: {
          title: 'NAVIGATION',
          description: 'Use the Menu to move between pages: Scenario Studio, Red Tools, Architecture, and Settings.',
          side: 'bottom', align: 'end'
        }
      },
      {
        element: '#qi',
        popover: {
          title: 'SEARCH SCENARIOS',
          description: 'Type to filter scenarios by name, tactic, or technique. Scenarios are grouped by Sophos product below.',
          side: 'bottom', align: 'start'
        }
      },
      {
        element: '#sl',
        popover: {
          title: 'SCENARIO LIBRARY',
          description: 'Scenarios are grouped by Sophos product \u2014 Endpoint, NDR, Firewall. Click any row to load its details. Star it to save as a favourite.',
          side: 'right', align: 'start'
        }
      },
      {
        element: '#rp',
        popover: {
          title: 'SCENARIO DETAILS',
          description: 'Shows expected Sophos detections, MITRE technique mapping, and talking points for the selected scenario.',
          side: 'left', align: 'start'
        }
      },
      {
        element: '#tgt',
        popover: {
          title: 'VICTIM IP',
          description: 'Enter the IP address of your Windows victim VM here.',
          side: 'top', align: 'start'
        }
      },
      {
        element: '#saved-targets',
        popover: {
          title: 'SAVED TARGETS',
          description: 'Save IPs with labels and click to auto-fill. Persists across sessions \u2014 great for reusing between demos.',
          side: 'top', align: 'start'
        }
      },
      {
        element: '#pngb',
        popover: {
          title: 'CONFIRM CONNECTION',
          description: 'Click Check to ping the victim. Before launching, confirm your victim VM\'s sandcat agent has checked in \u2014 it connects automatically on VM boot.',
          side: 'top', align: 'start'
        }
      },
      {
        element: '#lbtn',
        popover: {
          title: 'LAUNCH SIMULATION',
          description: 'Starts the CALDERA operation on your victim. The Attack Console opens automatically.',
          side: 'top', align: 'start',
          showButtons: ['previous', 'next'],
          nextBtnText: 'Done'
        }
      }
    ];
  }

  function consoleSteps() {
    // .lk elements are feed rows — only exist when an operation is active.
    // We build the step list dynamically so the ability-detail step is skipped
    // when no operation is running (no .lk elements in DOM).
    var steps = [
      {
        popover: {
          title: 'WATCH THE ATTACK UNFOLD',
          description: 'Live CALDERA feed on the left. Live RDP session to your victim on the right.',
          showButtons: ['next'],
          nextBtnText: 'Let\'s go \u2192'
        }
      },
      {
        element: '#feed',
        popover: {
          title: 'LIVE ATTACK FEED',
          description: 'Each row is a MITRE ATT&CK technique executing on your victim in real time.',
          side: 'right', align: 'start'
        }
      }
    ];

    if (document.querySelector('.lk')) {
      steps.push({
        element: '.lk',
        popover: {
          title: 'ABILITY DETAIL',
          description: 'Click any row to expand it and see the exact command that ran on the victim.',
          side: 'right', align: 'start'
        }
      });
    }

    steps.push(
      {
        element: '#op-state-txt',
        popover: {
          title: 'OPERATION STATUS',
          description: 'Shows whether the operation is running, complete, or stopped. Updates every 3 seconds.',
          side: 'bottom', align: 'start'
        }
      },
      {
        element: '#panel-r',
        popover: {
          title: 'LIVE VICTIM DESKTOP',
          description: 'Watch the attack happen on the victim in real time. Narrate what you see to the customer.',
          side: 'left', align: 'start'
        }
      },
      {
        element: '#panel-r',
        popover: {
          title: 'SOPHOS XDR PIVOT',
          description: 'When the attack completes, open Sophos XDR or Sophos Central to show the customer their real detections side-by-side.',
          side: 'left', align: 'start',
          showButtons: ['previous', 'next'],
          nextBtnText: 'Done'
        }
      }
    );

    return steps;
  }

  function adminSteps() {
    return [
      {
        popover: {
          title: 'BUILD YOUR OWN SCENARIOS',
          description: 'Two creation paths: AI-powered from plain English, or manual step-by-step design.',
          showButtons: ['next'],
          nextBtnText: 'Let\'s go \u2192'
        }
      },
      {
        element: '#create-cards',
        popover: {
          title: 'CREATE A SCENARIO',
          description: 'Choose your creation path: AI Generate builds a scenario from plain English. Design Scenario gives you full manual control.',
          side: 'bottom', align: 'center'
        }
      },
      {
        element: '#create-ai',
        popover: {
          title: 'AI GENERATE',
          description: 'Describe an attack in plain English. The AI builds a complete scenario with MITRE mapping, CALDERA abilities, and talking points.',
          side: 'bottom', align: 'start'
        },
        onHighlightStarted: function () {
          if (typeof openCreate === 'function') openCreate('ai');
        }
      },
      {
        element: '#ai-submit',
        popover: {
          title: 'SUBMIT CASE',
          description: 'Click Generate to send to the AI. It maps techniques, selects CALDERA abilities, and adds talking points automatically.',
          side: 'top', align: 'end'
        }
      },
      {
        element: '#create-design',
        popover: {
          title: 'MANUAL DESIGN',
          description: 'Prefer full control? Pick MITRE techniques directly, write your own detections and talking points.',
          side: 'bottom', align: 'start'
        },
        onHighlightStarted: function () {
          if (typeof openCreate === 'function') openCreate('design');
        }
      },
      {
        element: '#scenario-list',
        popover: {
          title: 'YOUR SCENARIOS',
          description: 'All scenarios live here \u2014 including AI-generated ones pending your review.',
          side: 'top', align: 'start'
        },
        onHighlightStarted: function () {
          var forms = document.getElementById('create-forms');
          if (forms) forms.style.display = 'none';
          var cards = document.getElementById('create-cards');
          if (cards) cards.style.display = '';
        }
      },
      {
        element: '#scenario-list',
        popover: {
          title: 'APPROVE & EDIT',
          description: 'Review AI-generated scenarios before they appear in the SE Console. Edit any field or delete if not needed.',
          side: 'top', align: 'start',
          showButtons: ['previous', 'next'],
          nextBtnText: 'Done'
        }
      }
    ];
  }

  function toolsSteps() {
    return [
      {
        popover: {
          title: 'MANUAL RED TEAM ACCESS',
          description: 'Browser-based terminal access to your red team containers for manual techniques beyond CALDERA.',
          showButtons: ['next'],
          nextBtnText: 'Let\'s go \u2192'
        }
      },
      {
        element: '#tab-kali',
        popover: {
          title: 'KALI LINUX',
          description: 'Opens a full Kali Linux terminal in your browser via Guacamole. Run any tool or script manually.',
          side: 'bottom', align: 'start'
        }
      },
      {
        element: '#tab-atomic',
        popover: {
          title: 'ATOMIC RED TEAM',
          description: 'Switch to the Atomic Red Team container to run Atomic tests directly via SSH.',
          side: 'bottom', align: 'start',
          showButtons: ['previous', 'next'],
          nextBtnText: 'Done'
        }
      }
    ];
  }

  function settingsSteps(opts) {
    var isLabops = opts.labops || opts.forceLabops;
    var steps = [
      {
        popover: {
          title: 'CONFIGURE THE PLATFORM',
          description: 'Set your AI provider for scenario generation' + (isLabops ? ' and connect to the Lab Manager.' : '.'),
          showButtons: ['next'],
          nextBtnText: 'Let\'s go \u2192'
        }
      },
      {
        element: '#stg-grid',
        popover: {
          title: 'AI PROVIDER',
          description: 'Choose Anthropic, OpenAI, Gemini, or local Ollama for scenario generation and enrichment.',
          side: 'bottom', align: 'start'
        }
      },
      {
        element: '#stg-key',
        popover: {
          title: 'API KEY',
          description: 'Enter your API key here. It\'s stored locally in ai-config.json and never leaves your machine.',
          side: 'bottom', align: 'start'
        }
      }
    ];
    if (isLabops) {
      steps.push({
        element: '#stg-labops-url',
        popover: {
          title: 'LAB MANAGER',
          description: 'Enter your LabOps URL to enable VM management directly from the SE Console nav.',
          side: 'bottom', align: 'start',
          showButtons: ['previous', 'next'],
          nextBtnText: 'Done'
        }
      });
    } else {
      steps[steps.length - 1].popover.showButtons = ['previous', 'next'];
      steps[steps.length - 1].popover.nextBtnText = 'Done';
    }
    return steps;
  }

  function architectureSteps(opts) {
    var isLabops = opts.labops || opts.forceLabops;
    return [
      {
        popover: {
          title: 'HOW IT ALL CONNECTS',
          description: isLabops
            ? 'A reference map of the two-repo setup (adversary-sim + LabOps) running on your Mac Mini. Great for troubleshooting.'
            : 'A reference map of the all-in-one stack running on your Mac Mini. Great for troubleshooting.',
          showButtons: ['next'],
          nextBtnText: 'Let\'s go \u2192'
        }
      },
      {
        element: '#arch-platform',
        popover: {
          title: 'PLATFORM STACK',
          description: 'Every Docker container, its IP address, port, and role. The full picture of what\'s running.',
          side: 'bottom', align: 'start'
        }
      },
      {
        element: '#arch-services',
        popover: {
          title: 'SERVICE REFERENCE',
          description: 'Quick lookup for ports, container names, and credentials. Bookmark this page.',
          side: 'bottom', align: 'start'
        }
      },
      {
        element: '#arch-scenarios',
        popover: {
          title: 'SCENARIO CATALOG',
          description: 'Full library of all 24 built-in scenarios with MITRE mappings and CALDERA adversary IDs.',
          side: 'bottom', align: 'start',
          showButtons: ['previous', 'next'],
          nextBtnText: 'You\'re all set! \u2713'
        }
      }
    ];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  function getSteps(page, opts) {
    switch (page) {
      case 'index':        return indexSteps();
      case 'console':      return consoleSteps();
      case 'admin':        return adminSteps();
      case 'tools':        return toolsSteps();
      case 'settings':     return settingsSteps(opts);
      case 'architecture': return architectureSteps(opts);
      default: return [];
    }
  }

  function getMode(opts) {
    if (opts && opts.forceLabops) return Promise.resolve({ labops: true });
    return fetch('/ai-config.json')
      .then(function (r) { return r.json(); })
      .then(function (cfg) { return { labops: !!(cfg && cfg.labopsUrl) }; })
      .catch(function () { return { labops: false }; });
  }

  function showCrossPagePrompt(page) {
    var next = NEXT_PAGE[page];
    removeCrossPagePrompt();
    var el = document.createElement('div');
    el.id = 'tour-xpage';
    if (next) {
      el.innerHTML =
        '<span>Getting Started Tour: Next up \u2014 <strong>' + next.label + '</strong></span>' +
        '<div class="tour-xpage-btns">' +
        '<button id="tour-xpage-go">Continue \u2192</button>' +
        '<button id="tour-xpage-skip">Finish Tour</button>' +
        '</div>';
      el.querySelector('#tour-xpage-go').addEventListener('click', function () {
        localStorage.setItem(PAGE_KEY, next.page);
        removeCrossPagePrompt();
        window.open(next.url, '_blank');
      });
      el.querySelector('#tour-xpage-skip').addEventListener('click', function () {
        localStorage.removeItem(PAGE_KEY);
        removeCrossPagePrompt();
      });
    } else {
      // Architecture page — tour complete
      localStorage.setItem(DONE_KEY, '1');
      localStorage.removeItem(PAGE_KEY);
      el.innerHTML =
        '<span>\uD83C\uDF89 Tour complete! You\'re ready to run live attack simulations.</span>' +
        '<div class="tour-xpage-btns">' +
        '<button id="tour-xpage-done">Back to SE Console</button>' +
        '</div>';
      el.querySelector('#tour-xpage-done').addEventListener('click', function () {
        removeCrossPagePrompt();
        window.location.href = '/index.html';
      });
    }
    document.body.appendChild(el);
  }

  function removeCrossPagePrompt() {
    var el = document.getElementById('tour-xpage');
    if (el) el.remove();
  }

  function showContinueBanner(page, onContinue) {
    removeContinueBanner();
    var name = PAGE_NAMES[page] || page;
    var el = document.createElement('div');
    el.id = 'tour-banner';
    el.innerHTML =
      '<span>Getting Started Tour: continuing on <strong>' + name + '</strong></span>' +
      '<button id="tour-banner-cont">Continue</button>' +
      '<button id="tour-banner-dis">Dismiss</button>';
    document.body.insertBefore(el, document.body.firstChild);

    var timeout = setTimeout(function () {
      localStorage.removeItem(PAGE_KEY);
      removeContinueBanner();
    }, 8000);

    el.querySelector('#tour-banner-cont').addEventListener('click', function () {
      clearTimeout(timeout);
      localStorage.removeItem(PAGE_KEY);
      removeContinueBanner();
      onContinue();
    });
    el.querySelector('#tour-banner-dis').addEventListener('click', function () {
      clearTimeout(timeout);
      localStorage.removeItem(PAGE_KEY);
      removeContinueBanner();
    });
  }

  function removeContinueBanner() {
    var el = document.getElementById('tour-banner');
    if (el) el.remove();
  }

  // ── Tour launcher ─────────────────────────────────────────────────────────

  var _mode = { labops: false };
  var _currentPage = '';

  function launchTour(page, gettingStarted, skipIntro) {
    var opts = Object.assign({}, _mode);
    var steps = getSteps(page, opts);
    if (skipIntro) steps = steps.slice(1);

    // Track whether user completed tour naturally vs dismissed early.
    // onDestroyStarted fires before destroy — drv.hasNextStep() false = natural completion.
    var _completedNaturally = false;

    var drv = window.driver.js.driver({
      animate: true,
      showProgress: true,
      allowClose: true,
      stagePadding: 6,
      steps: steps,
      onDestroyStarted: function () {
        _completedNaturally = !drv.hasNextStep();
        drv.destroy();
      },
      onDestroyed: function () {
        if (gettingStarted) {
          localStorage.setItem(DONE_KEY, '1');
          if (_completedNaturally) {
            showCrossPagePrompt(page);
          }
        }
      }
    });
    drv.drive();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  window.initTour = function (page, opts) {
    _currentPage = page;
    opts = opts || {};

    // Wire ? help button immediately — DOM is ready since tour.js loads at end of body
    var helpBtn = document.getElementById('tour-help-btn');
    if (helpBtn) {
      helpBtn.addEventListener('click', function () {
        launchTour(page, false, false);
      });
    }

    getMode(opts).then(function (mode) {
      _mode = Object.assign({}, mode, opts);

      // ?tour=1 param — triggered by Start Tour link
      var params = new URLSearchParams(window.location.search);
      if (params.get('tour') === '1') {
        window.history.replaceState({}, '', window.location.pathname);
        launchTour(page, true, false);
        return;
      }

      // Continue banner from cross-page prompt
      var continuePage = localStorage.getItem(PAGE_KEY);
      if (continuePage === page) {
        showContinueBanner(page, function () {
          launchTour(page, true, true);
        });
        return;
      }

      // Auto-launch on index if first visit
      if (page === 'index' && !localStorage.getItem(DONE_KEY)) {
        function tryLaunch() {
          var sl = document.getElementById('sl');
          if (sl && sl.children.length > 0) {
            setTimeout(function () { launchTour(page, true, false); }, 800);
          } else {
            setTimeout(tryLaunch, 300);
          }
        }
        tryLaunch();
      }
    });
  };

}());
```

- [ ] **Step 3: Verify the file was created**

```bash
wc -l nginx/html/tour.js
```
Expected: ~520 lines

- [ ] **Step 4: Commit**

```bash
git add nginx/html/tour.js
git commit -m "feat: add tour.js with Driver.js step definitions for all 6 pages"
```

---

## Task 2: Add CSS theme and tour UI styles to shared.css

**Files:**
- Modify: `nginx/html/shared.css` (append to end of file)

- [ ] **Step 1: Append the tour styles to the end of shared.css**

```css
/* ── Guided Tour ─────────────────────────────────────────────────────────── */

/* ? help button — appears in every page header */
.tour-help-btn {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  border: 1px solid rgba(0, 229, 255, 0.4);
  color: #00e5ff;
  background: transparent;
  cursor: pointer;
  font-size: 13px;
  font-family: var(--fm);
  display: flex;
  align-items: center;
  justify-content: center;
  transition: border-color 0.15s, box-shadow 0.15s;
  flex-shrink: 0;
  line-height: 1;
}
.tour-help-btn:hover {
  border-color: #00e5ff;
  box-shadow: 0 0 8px rgba(0, 229, 255, 0.2);
}

/* Continue Tour? banner — fixed at top of page */
#tour-banner {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 10000;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  background: rgba(0, 229, 255, 0.08);
  border-bottom: 1px solid rgba(0, 229, 255, 0.2);
  font-size: 12px;
  color: #e2e8f0;
  font-family: var(--fm);
}
#tour-banner button {
  font-size: 11px;
  font-family: var(--fm);
  background: transparent;
  border: 1px solid rgba(0, 229, 255, 0.4);
  color: #00e5ff;
  border-radius: 4px;
  padding: 2px 10px;
  cursor: pointer;
}
#tour-banner button:last-child {
  color: #64748b;
  border-color: rgba(100, 116, 139, 0.3);
}

/* Cross-page next-up prompt — fixed bottom-right */
#tour-xpage {
  position: fixed;
  bottom: 24px;
  right: 24px;
  z-index: 10000;
  background: #111827;
  border: 1px solid rgba(0, 229, 255, 0.4);
  border-radius: 10px;
  padding: 16px 20px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  font-size: 13px;
  color: #e2e8f0;
  font-family: var(--fm);
  box-shadow: 0 0 24px rgba(0, 229, 255, 0.15);
  max-width: 300px;
  line-height: 1.5;
}
.tour-xpage-btns {
  display: flex;
  gap: 8px;
}
#tour-xpage button {
  font-size: 11px;
  font-family: var(--fm);
  padding: 5px 14px;
  border-radius: 4px;
  cursor: pointer;
  background: transparent;
}
#tour-xpage #tour-xpage-go,
#tour-xpage #tour-xpage-done {
  border: 1px solid #00e5ff;
  color: #00e5ff;
}
#tour-xpage #tour-xpage-skip {
  border: 1px solid rgba(100, 116, 139, 0.3);
  color: #64748b;
}

/* ── Driver.js theme overrides ──────────────────────────────────────────── */
.driver-popover {
  background: #111827 !important;
  border: 1px solid rgba(0, 229, 255, 0.4) !important;
  box-shadow: 0 0 24px rgba(0, 229, 255, 0.15) !important;
  border-radius: 10px !important;
  max-width: 280px !important;
  font-family: var(--fm) !important;
}
.driver-popover-title {
  color: #00e5ff !important;
  font-family: 'JetBrains Mono', monospace !important;
  font-size: 10px !important;
  letter-spacing: 1.5px !important;
  text-transform: uppercase !important;
  font-weight: 500 !important;
  margin-bottom: 8px !important;
}
.driver-popover-description {
  color: #e2e8f0 !important;
  font-size: 12px !important;
  line-height: 1.6 !important;
}
.driver-popover-progress-text {
  color: #64748b !important;
  font-size: 10px !important;
}
.driver-popover-next-btn {
  background: transparent !important;
  border: 1px solid #00e5ff !important;
  color: #00e5ff !important;
  border-radius: 4px !important;
  padding: 4px 12px !important;
  font-size: 11px !important;
  font-family: var(--fm) !important;
  text-shadow: none !important;
}
.driver-popover-next-btn:hover {
  background: rgba(0, 229, 255, 0.08) !important;
}
.driver-popover-prev-btn,
.driver-popover-close-btn {
  color: #64748b !important;
  background: transparent !important;
  border: none !important;
  font-size: 11px !important;
  font-family: var(--fm) !important;
  text-shadow: none !important;
}
.driver-overlay {
  background: rgba(0, 0, 0, 0.75) !important;
}
.driver-highlighted-element {
  border: 2px solid rgba(0, 229, 255, 0.6) !important;
  box-shadow: 0 0 0 4px rgba(0, 229, 255, 0.12), 0 0 20px rgba(0, 229, 255, 0.2) !important;
  border-radius: 6px !important;
}
```

- [ ] **Step 2: Verify styles appended**

```bash
tail -5 nginx/html/shared.css
```
Expected: last line is `}` closing `.driver-highlighted-element`

- [ ] **Step 3: Commit**

```bash
git add nginx/html/shared.css
git commit -m "feat: add Driver.js theme and tour UI styles to shared.css"
```

---

## Task 3: Wire tour into index.html

**Files:**
- Modify: `nginx/html/index.html`

- [ ] **Step 1: Add Driver.js CDN links in `<head>`**

Find `<link rel="stylesheet" href="shared.css">` and add immediately after it:

```html
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/driver.js@1/dist/driver.css"/>
  <script src="https://cdn.jsdelivr.net/npm/driver.js@1/dist/driver.iife.js"></script>
```

- [ ] **Step 2: Add `?` button in `#hdr-controls`**

Find `<div class="nav-wrap" id="nav-wrap">` inside `#hdr-controls` and insert immediately before it:

```html
        <button class="tour-help-btn" id="tour-help-btn" title="Page help">?</button>
```

- [ ] **Step 3: Add Start Tour as first item in `#nav-dd`**

Find the first `<button class="nav-it"` inside `#nav-dd` and insert before it:

```html
              <button class="nav-it" onclick="window.location.href='/index.html?tour=1'">&#9658; Start Tour</button>
```

- [ ] **Step 4: Add initTour call before `</body>`**

After the last `</script>` tag and before `</body>`:

```html
<script src="/tour.js"></script>
<script>initTour('index');</script>
```

- [ ] **Step 5: Manual test**

```bash
docker restart advsim-nginx
```

Open `http://localhost:8081` in an **incognito window** (clean localStorage).

Expected:
- Tour auto-launches ~1s after page load with "Welcome to the SE Console" intro card
- Clicking "Let's go →" steps through all 9 spotlight steps with cyan glow on each element
- Clicking Done shows "Next up: Attack Console →" prompt in bottom-right corner
- Pressing Escape mid-tour dismisses without showing the cross-page prompt
- `?` button in top-right launches per-page tour (no cross-page prompt at end)
- "▶ Start Tour" in nav menu relaunches tour from intro card

- [ ] **Step 6: Commit**

```bash
git add nginx/html/index.html
git commit -m "feat: wire guided tour into index.html"
```

---

## Task 4: Wire tour into console.html

**Files:**
- Modify: `nginx/html/console.html`

**Note:** `console.html` has no `#hdr-controls`. Its header is `<header id="hdr">` with `.hdr-right` containing `#nav-wrap`. Place the `?` button inside `.hdr-right`.

- [ ] **Step 1: Add Driver.js CDN in `<head>`** (same as Task 3 Step 1)

- [ ] **Step 2: Add `?` button inside `.hdr-right`**

Find `<div class="nav-wrap" id="nav-wrap">` inside `.hdr-right` and insert immediately before it:

```html
        <button class="tour-help-btn" id="tour-help-btn" title="Page help">?</button>
```

- [ ] **Step 3: Add Start Tour as first item in `#nav-dd`** (same as Task 3 Step 3)

- [ ] **Step 4: Add initTour call before `</body>`**

```html
<script src="/tour.js"></script>
<script>initTour('console');</script>
```

- [ ] **Step 5: Manual test**

```bash
docker restart advsim-nginx
```

Open `http://localhost:8081/console.html`.

Expected:
- `?` button runs 5-step tour (6 if an operation is active and `.lk` rows exist): intro → feed → [ability detail if .lk present] → status → RDP panel → XDR pivot
- "Continue Tour?" banner appears if `advsim_tour_page = "console"` is set in localStorage from the SE Console cross-page prompt

- [ ] **Step 6: Commit**

```bash
git add nginx/html/console.html
git commit -m "feat: wire guided tour into console.html"
```

---

## Task 5: Wire tour into admin.html

**Files:**
- Modify: `nginx/html/admin.html`

**Note:** `admin.html` uses `.shared-hdr-right` (not `#hdr-controls`) as the wrapper around `#nav-wrap`.

- [ ] **Step 1: Add Driver.js CDN in `<head>`**

- [ ] **Step 2: Add `?` button inside `.shared-hdr-right`**

Find `<div class="nav-wrap" id="nav-wrap">` inside `.shared-hdr-right` and insert immediately before it:

```html
        <button class="tour-help-btn" id="tour-help-btn" title="Page help">?</button>
```

- [ ] **Step 3: Add Start Tour as first item in `#nav-dd`**

- [ ] **Step 4: Add initTour call before `</body>`**

```html
<script src="/tour.js"></script>
<script>initTour('admin');</script>
```

- [ ] **Step 5: Manual test**

```bash
docker restart advsim-nginx
```

Open `http://localhost:8081/admin.html`.

Expected:
- 7-step tour: intro → create-cards → AI form panel opens automatically → submit button → design form panel switches automatically → scenario list → approve/edit
- `openCreate('ai')` and `openCreate('design')` callbacks switch form panels before each spotlight

- [ ] **Step 6: Commit**

```bash
git add nginx/html/admin.html
git commit -m "feat: wire guided tour into admin.html"
```

---

## Task 6: Wire tour into tools.html

**Files:**
- Modify: `nginx/html/tools.html`

**Note:** `tools.html` has no `#nav-dd` dropdown. Both the `?` button and a Tour text link go in `.hdr-right`.

- [ ] **Step 1: Add Driver.js CDN in `<head>`**

- [ ] **Step 2: Add `?` button and Tour link in `.hdr-right`**

Find `<div class="hdr-right">` and insert the following before the existing DONE button:

```html
      <button class="nav-it" onclick="window.location.href='/index.html?tour=1'" style="font-size:11px;padding:4px 10px;border:1px solid rgba(0,229,255,.3);border-radius:4px;color:#64748b;background:transparent;cursor:pointer;margin-right:8px;">&#9658; Tour</button>
      <button class="tour-help-btn" id="tour-help-btn" title="Page help" style="margin-right:8px;">?</button>
```

- [ ] **Step 3: Add initTour call before `</body>`**

```html
<script src="/tour.js"></script>
<script>initTour('tools');</script>
```

- [ ] **Step 4: Manual test**

```bash
docker restart advsim-nginx
```

Open `http://localhost:8081/tools.html`.

Expected:
- 3-step tour: intro → Kali tab → Atomic tab
- Both `?` and `▶ Tour` buttons visible in top-right header

- [ ] **Step 5: Commit**

```bash
git add nginx/html/tools.html
git commit -m "feat: wire guided tour into tools.html"
```

---

## Task 7: Wire tour into settings.html

**Files:**
- Modify: `nginx/html/settings.html`

- [ ] **Step 1: Add Driver.js CDN in `<head>`**

- [ ] **Step 2: Add `?` button in `#hdr-controls`** (same pattern as index.html — `#hdr-controls` exists here)

- [ ] **Step 3: Add Start Tour as first item in `#nav-dd`**

- [ ] **Step 4: Add initTour call before `</body>`**

```html
<script src="/tour.js"></script>
<script>initTour('settings');</script>
```

- [ ] **Step 5: Manual test**

```bash
docker restart advsim-nginx
```

Open `http://localhost:8081/settings.html`.

Expected:
- Standalone mode (no `labopsUrl` in ai-config.json): 3-step tour — intro, provider, API key. Done button on step 3.
- LabOps mode (`labopsUrl` set): 4-step tour — Lab Manager URL step appears as step 4.
- To test LabOps mode: open `nginx/html/ai-config.json`, temporarily set `"labopsUrl": "http://localhost:8080"`, restart nginx, reload, run tour.

- [ ] **Step 6: Commit**

```bash
git add nginx/html/settings.html
git commit -m "feat: wire guided tour into settings.html"
```

---

## Task 8: Wire tour into architecture.html + add section IDs

**Files:**
- Modify: `nginx/html/architecture.html`

- [ ] **Step 1: Add 3 `id` attributes to section headings**

Find `<h2 class="section-hdr">Platform Architecture</h2>` (~line 471). Change to:
```html
      <h2 class="section-hdr" id="arch-platform">Platform Architecture</h2>
```

Find `<h2 class="section-hdr collapsible" onclick="toggleSection(this)">Services &amp; Ports</h2>` (~line 538). Change to:
```html
      <h2 class="section-hdr collapsible" id="arch-services" onclick="toggleSection(this)">Services &amp; Ports</h2>
```

Find `<h2 class="section-hdr collapsible" onclick="toggleSection(this)">Scenario Library &mdash; 24 Scenarios</h2>` (~line 646). Change to:
```html
      <h2 class="section-hdr collapsible" id="arch-scenarios" onclick="toggleSection(this)">Scenario Library &mdash; 24 Scenarios</h2>
```

- [ ] **Step 2: Add Driver.js CDN in `<head>`**

- [ ] **Step 3: Add `?` button in `#hdr-controls`** (same as index.html)

- [ ] **Step 4: Add Start Tour as first item in `#nav-dd`**

- [ ] **Step 5: Add initTour call before `</body>`**

```html
<script src="/tour.js"></script>
<script>initTour('architecture');</script>
```

- [ ] **Step 6: Manual test**

```bash
docker restart advsim-nginx
```

Open `http://localhost:8081/architecture.html`.

Expected:
- 4-step tour: intro → Platform Architecture → Services & Ports → Scenario Library
- Standalone mode: intro says "all-in-one stack"
- LabOps mode: intro says "two-repo setup"
- "You're all set! ✓" on last step → tour-complete cross-page card appears with "Back to SE Console" button

**Full end-to-end test:** Clear localStorage (`localStorage.clear()` in browser console), load `http://localhost:8081`, complete the full Getting Started tour across all 6 pages by following the cross-page prompts. Verify tour-complete card appears on architecture.html and "Back to SE Console" navigates correctly.

- [ ] **Step 7: Commit**

```bash
git add nginx/html/architecture.html
git commit -m "feat: wire guided tour into architecture.html, add section IDs"
```

---

## Task 9: Port guided tour to mdr-demo-lab

**Files:**
- Create: `../mdr-demo-lab/nginx/html/tour.js`
- Modify: `../mdr-demo-lab/nginx/html/shared.css`
- Modify: all 6 HTML pages in `../mdr-demo-lab/nginx/html/`

**Key difference:** mdr-demo-lab always shows the Lab Manager URL step in Settings regardless of `ai-config.json`. Pass `{ forceLabops: true }` to `initTour()` on `settings.html` only. All other pages use `initTour('page-name')` with no options.

- [ ] **Step 1: Create feature branch in mdr-demo-lab**

```bash
cd ../mdr-demo-lab
git checkout -b feat/guided-tour
```

- [ ] **Step 2: Copy tour.js to mdr-demo-lab**

```bash
cp ../adversary-sim/nginx/html/tour.js nginx/html/tour.js
```

- [ ] **Step 3: Append the same CSS block to mdr-demo-lab shared.css**

Copy the entire `/* ── Guided Tour ── */` block from Task 2 and append to `../mdr-demo-lab/nginx/html/shared.css`.

- [ ] **Step 4: Wire all 6 HTML pages**

Repeat Tasks 3–8 for `../mdr-demo-lab/nginx/html/`. All selectors are identical. The only difference:

In `../mdr-demo-lab/nginx/html/settings.html`, the initTour call is:
```html
<script src="/tour.js"></script>
<script>initTour('settings', { forceLabops: true });</script>
```

All other 5 pages use `initTour('page-name')` with no second argument.

- [ ] **Step 5: Test mdr-demo-lab**

If the mdr-demo-lab nginx container is running, restart it. Open its SE Console URL and verify:
- Tour auto-launches on first visit
- Settings always shows the Lab Manager URL step (step 4) regardless of `ai-config.json`

- [ ] **Step 6: Commit mdr-demo-lab**

```bash
git add nginx/html/tour.js nginx/html/shared.css nginx/html/index.html nginx/html/console.html nginx/html/admin.html nginx/html/tools.html nginx/html/settings.html nginx/html/architecture.html
git commit -m "feat: add guided tour to all 6 pages (port from adversary-sim)"
```

- [ ] **Step 7: Merge to main in mdr-demo-lab**

```bash
git checkout main
git merge feat/guided-tour
```

- [ ] **Step 8: Merge feat/guided-tour to main in adversary-sim**

```bash
cd ../adversary-sim
git checkout main
git merge feat/guided-tour
```
