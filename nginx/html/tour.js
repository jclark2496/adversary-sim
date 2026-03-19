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
