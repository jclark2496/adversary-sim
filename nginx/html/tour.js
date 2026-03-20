// nginx/html/tour.js
// Per-page guided tour — Driver.js v1 wrapper for all 6 SE Console pages.
// Loaded by each page just before </body>. Each page calls initTour('page-name').
// DOM is already ready when this runs — never use DOMContentLoaded here.

(function () {
  'use strict';

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
        },
        onHighlightStarted: function () {
          var first = document.querySelector('.srow');
          if (first) first.click();
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
          side: 'top', align: 'start'
        }
      },
      {
        element: '#nav-btn',
        popover: {
          title: 'NAVIGATION MENU',
          description: 'Use <strong>Menu</strong> to access all pages of the platform:<br><br>' +
            '\u2022 <strong>Attack Console</strong> \u2014 Watch live CALDERA operations and victim desktop<br>' +
            '\u2022 <strong>Scenario Studio</strong> \u2014 Build and manage attack scenarios with AI or manual design<br>' +
            '\u2022 <strong>Red Tools</strong> \u2014 Browser-based Kali Linux, Atomic Red Team, and CALDERA access<br>' +
            '\u2022 <strong>Architecture</strong> \u2014 Platform reference, service map, and scenario catalog<br>' +
            '\u2022 <strong>Settings</strong> \u2014 Configure your AI provider and Lab Manager URL',
          side: 'bottom', align: 'end',
          showButtons: ['previous', 'next'],
          nextBtnText: 'Done \u2713'
        }
      }
    ];
  }

  function consoleSteps() {
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
          side: 'top', align: 'start'
        }
      },
      {
        element: '#panel-r',
        popover: {
          title: 'SOPHOS XDR PIVOT',
          description: 'When the attack completes, open Sophos XDR or Sophos Central to show the customer their real detections side-by-side.',
          side: 'top', align: 'start',
          showButtons: ['previous', 'next'],
          nextBtnText: 'Done \u2713'
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
          nextBtnText: 'Done \u2713'
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
          side: 'bottom', align: 'start'
        }
      },
      {
        element: '#tab-caldera',
        popover: {
          title: 'CALDERA CONSOLE',
          description: 'Direct access to the CALDERA web interface \u2014 manage operations, agents, abilities, and adversary profiles.',
          side: 'bottom', align: 'start'
        }
      },
      {
        element: '#panel-r',
        popover: {
          title: 'WINDOWS HOST',
          description: 'RDP session to your victim VM. Use this alongside manual red team tools to watch techniques land in real time.',
          side: 'top', align: 'start',
          showButtons: ['previous', 'next'],
          nextBtnText: 'Done \u2713'
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
          side: 'bottom', align: 'start'
        }
      });
    }
    steps.push({
      element: '#upd-local-ver',
      popover: {
        title: 'PLATFORM UPDATE',
        description: 'Check the current version and pull updates directly from this page. No reinstall needed.',
        side: 'top', align: 'start',
        showButtons: ['previous', 'next'],
        nextBtnText: 'Done \u2713'
      }
    });
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
        element: '#arch-flow',
        popover: {
          title: 'ATTACK FLOW',
          description: 'The end-to-end kill chain: SE Console \u2192 CALDERA operation \u2192 sandcat agent \u2192 techniques execute on victim \u2192 Sophos detects \u2192 SE pivots to XDR.',
          side: 'bottom', align: 'start'
        }
      },
      {
        element: '#arch-scenarios',
        popover: {
          title: 'SCENARIO CATALOG',
          description: 'Full library of all built-in scenarios with MITRE mappings and CALDERA adversary IDs.',
          side: 'top', align: 'start',
          showButtons: ['previous', 'next'],
          nextBtnText: 'Done \u2713'
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

  // ── Tour launcher ─────────────────────────────────────────────────────────

  var _mode = { labops: false };

  function launchTour(page) {
    var opts = Object.assign({}, _mode);
    var steps = getSteps(page, opts);

    window.driver.js.driver({
      animate: true,
      showProgress: true,
      allowClose: true,
      stagePadding: 6,
      overlayOpacity: 0.3,
      steps: steps
    }).drive();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  window.initTour = function (page, opts) {
    opts = opts || {};

    var helpBtn = document.getElementById('tour-help-btn');
    if (helpBtn) {
      helpBtn.addEventListener('click', function () {
        launchTour(page);
      });
    }

    getMode(opts).then(function (mode) {
      _mode = Object.assign({}, mode, opts);
    });
  };

}());
