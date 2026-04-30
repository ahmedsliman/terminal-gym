/* ── terminal-gym web frontend ──────────────────────────────────────────── */

(function () {
  "use strict";

  // ── State ──────────────────────────────────────────────────────────────
  let content     = null;   // from /api/content
  let grades      = {};     // { missionNum: { page_N: { done: [...] } } }
  let missionIdx  = 0;
  let pageIdx     = 0;
  let sections    = {};     // { sectionName: expanded }
  let focusPanel  = "missions";  // "missions" | "exercises" | "terminal"

  // ── DOM refs ───────────────────────────────────────────────────────────
  const $missions   = document.getElementById("missions-list");
  const $exercises  = document.getElementById("exercises-content");
  const $exTitle    = document.getElementById("exercises-title");
  const $pageNav    = document.getElementById("page-nav");
  const $exProgress = document.getElementById("exercises-progress");
  const $termTitle  = document.getElementById("terminal-title");
  const $termHint   = document.getElementById("terminal-hint");
  const $termBox    = document.getElementById("terminal-container");
  const $statusLeft = document.getElementById("status-left");
  const $statusRight = document.getElementById("status-right");
  const $counter    = document.getElementById("progress-counter");
  const $resize     = document.getElementById("resize-handle");

  // ── xterm.js + WebSocket ───────────────────────────────────────────────
  let term = null;
  let fitAddon = null;
  let ws = null;

  function initTerminal() {
    term = new Terminal({
      fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
      fontSize: 13,
      lineHeight: 1.3,
      cursorBlink: true,
      cursorStyle: "block",
      theme: {
        background:     "#1e1e2e",
        foreground:     "#cdd6f4",
        cursor:         "#f5e0dc",
        selectionBackground: "rgba(137,180,250,0.3)",
        black:   "#45475a", brightBlack:   "#585b70",
        red:     "#f38ba8", brightRed:     "#f38ba8",
        green:   "#a6e3a1", brightGreen:   "#a6e3a1",
        yellow:  "#f9e2af", brightYellow:  "#f9e2af",
        blue:    "#89b4fa", brightBlue:    "#89b4fa",
        magenta: "#f5c2e7", brightMagenta: "#f5c2e7",
        cyan:    "#94e2d5", brightCyan:    "#94e2d5",
        white:   "#bac2de", brightWhite:   "#a6adc8",
      },
    });

    fitAddon = new FitAddon.FitAddon();
    term.loadAddon(fitAddon);
    term.loadAddon(new WebLinksAddon.WebLinksAddon());

    term.open($termBox);
    fitAddon.fit();

    // Focus management
    term.textarea.addEventListener("focus", () => setFocus("terminal"));

    connectWebSocket();

    // Resize observer
    const ro = new ResizeObserver(() => {
      fitAddon.fit();
      sendResize();
    });
    ro.observe($termBox);
  }

  function connectWebSocket() {
    const proto = location.protocol === "https:" ? "wss:" : "ws:";
    ws = new WebSocket(`${proto}//${location.host}/ws/terminal`);
    ws.binaryType = "arraybuffer";

    ws.addEventListener("open", () => {
      $termHint.textContent = "connected";
      sendResize();
    });

    ws.addEventListener("message", (e) => {
      if (e.data instanceof ArrayBuffer) {
        term.write(new Uint8Array(e.data));
      } else if (typeof e.data === "string") {
        try {
          const msg = JSON.parse(e.data);
          if (msg.type === "grade") {
            // Update grades and re-render
            const mNum = msg.mission;
            const pageKey = "page_" + msg.page;
            if (!grades[mNum]) grades[mNum] = {};
            grades[mNum][pageKey] = {
              title: msg.title,
              expected: msg.expected,
              done: msg.done,
            };
            saveGrades();
            renderMissions();
            renderExercises();
            renderStatus();
            flashMessage(`✓  ${msg.title}  —  ${msg.done.length}/${msg.expected.length} done`);
          }
        } catch (err) { /* ignore non-JSON text */ }
      }
    });

    ws.addEventListener("close", () => {
      $termHint.textContent = "disconnected — click to reconnect";
      term.write("\r\n\x1b[31m[session ended]\x1b[0m\r\n");
    });

    ws.addEventListener("error", () => {
      $termHint.textContent = "connection error";
    });

    // Forward terminal input to server
    term.onData((data) => {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(new TextEncoder().encode(data));
      }
    });
  }

  function sendResize() {
    if (ws && ws.readyState === WebSocket.OPEN && term) {
      ws.send(JSON.stringify({
        type: "resize",
        rows: term.rows,
        cols: term.cols,
      }));
    }
  }

  // ── Reconnect on click ─────────────────────────────────────────────────
  $termHint.addEventListener("click", () => {
    if (!ws || ws.readyState === WebSocket.CLOSED) {
      term.clear();
      connectWebSocket();
    }
  });

  // ── Content loading ────────────────────────────────────────────────────
  async function loadContent() {
    const res = await fetch("/api/content");
    content = await res.json();

    // Init section expanded state
    for (const s of content.sections) {
      sections[s.name] = true;
    }

    renderMissions();
    renderExercises();
    renderStatus();
  }

  // ── Missions tree ──────────────────────────────────────────────────────
  function renderMissions() {
    const m = content.missions;
    let html = "";

    for (const sec of content.sections) {
      const expanded = sections[sec.name];
      const arrow = expanded ? "\u25bc" : "\u25b6";

      html += `<div class="section-header" data-section="${sec.name}">
        <span class="section-arrow">${arrow}</span>
        <span>${sec.name}</span>
      </div>`;

      if (expanded) {
        for (const num of sec.missions) {
          const mi = m.findIndex((x) => x.num === num);
          if (mi < 0) continue;
          const mission = m[mi];
          const active = mi === missionIdx ? " active" : "";
          const mark = missionMark(mission);

          html += `<div class="mission-item${active}" data-idx="${mi}">
            <span class="mission-mark ${mark.cls}">${mark.ch}</span>
            <span class="mission-num">${mission.num}</span>
            <span>${mission.name}</span>
          </div>`;
        }
      }
    }

    $missions.innerHTML = html;

    // Overall progress counter
    const done = m.filter((mm) => {
      const p = missionProgress(mm);
      return p.done >= p.total && p.total > 0;
    }).length;
    $counter.textContent = `${done}/${m.length}`;

    // Event handlers
    $missions.querySelectorAll(".section-header").forEach((el) => {
      el.addEventListener("click", () => {
        const name = el.dataset.section;
        sections[name] = !sections[name];
        renderMissions();
      });
    });

    $missions.querySelectorAll(".mission-item").forEach((el) => {
      el.addEventListener("click", () => {
        missionIdx = parseInt(el.dataset.idx);
        pageIdx = 0;
        renderMissions();
        renderExercises();
        renderStatus();
      });
    });
  }

  function missionMark(mission) {
    const p = missionProgress(mission);
    if (p.total === 0) return { ch: "\u00b7", cls: "none" };
    if (p.done >= p.total) return { ch: "\u2713", cls: "done" };
    if (p.done > 0) return { ch: "~", cls: "partial" };
    return { ch: "\u00b7", cls: "none" };
  }

  function missionProgress(mission) {
    let done = 0, total = 0;
    const mg = grades[mission.num] || {};
    for (let pi = 0; pi < mission.pages.length; pi++) {
      const page = mission.pages[pi];
      total += page.expected.length;
      const pg = mg[`page_${pi}`] || {};
      done += (pg.done || []).length;
    }
    return { done, total };
  }

  // ── Exercises ──────────────────────────────────────────────────────────
  function renderExercises() {
    const mission = content.missions[missionIdx];
    const pages = mission.pages;
    const page = pages[pageIdx];

    $exTitle.textContent = `EXERCISES  ${mission.num} \u00b7 ${mission.name}`;

    // Page nav
    if (pages.length > 1) {
      const prevCls = pageIdx === 0 ? " disabled" : "";
      const nextCls = pageIdx >= pages.length - 1 ? " disabled" : "";
      $pageNav.innerHTML =
        `<span class="nav-btn${prevCls}" id="page-prev">\u25c0</span>` +
        ` ${pageIdx + 1}/${pages.length} ` +
        `<span class="nav-btn${nextCls}" id="page-next">\u25b6</span>`;

      document.getElementById("page-prev")?.addEventListener("click", () => {
        if (pageIdx > 0) { pageIdx--; renderExercises(); }
      });
      document.getElementById("page-next")?.addEventListener("click", () => {
        if (pageIdx < pages.length - 1) { pageIdx++; renderExercises(); }
      });
    } else {
      $pageNav.textContent = "";
    }

    // Progress bar
    const pg = pageProgress(mission.num, pageIdx, page);
    if (pg.total > 0) {
      const barLen = 20;
      const filled = Math.round(barLen * pg.done / pg.total);
      const bar = "\u2588".repeat(filled) + "\u2591".repeat(barLen - filled);
      const cls = pg.done >= pg.total ? "done" : "";
      const label = pg.done >= pg.total
        ? "\u2713  All exercises complete!"
        : `${pg.done}/${pg.total}`;
      $exProgress.innerHTML =
        `<span class="progress-bar">` +
        `<span class="bar"><span class="filled">${"\u2588".repeat(filled)}</span>` +
        `<span class="empty">${"\u2591".repeat(barLen - filled)}</span></span>` +
        `<span class="score ${cls}">${label}</span></span>`;
    } else {
      $exProgress.innerHTML = "";
    }

    // Render page content
    let html = renderMarkdown(page);

    // Expected commands
    if (page.expected.length > 0) {
      const mg = grades[mission.num] || {};
      const pgGrade = mg[`page_${pageIdx}`] || {};
      const doneSet = new Set(pgGrade.done || []);

      html += `<div class="expected-section">`;
      html += `<div class="expected-title">Expected commands:</div>`;
      for (const exp of page.expected) {
        const hit = doneSet.has(exp);
        const tickCls = hit ? "done" : "";
        const tick = hit ? "\u2713" : "\u25cb";
        html += `<div class="expected-cmd">
          <span class="expected-tick ${tickCls}">${tick}</span>
          <code>${esc(exp)}</code>
        </div>`;
      }
      html += `</div>`;
    }

    $exercises.innerHTML = html;
  }

  function pageProgress(mnum, pi, page) {
    const mg = grades[mnum] || {};
    const pg = mg[`page_${pi}`] || {};
    return {
      done: (pg.done || []).length,
      total: page.expected.length,
    };
  }

  // ── Markdown renderer ──────────────────────────────────────────────────
  function renderMarkdown(page) {
    let html = "";
    let skipTitle = true;

    for (const raw of page.lines) {
      const s = raw.trimEnd();

      // Skip the heading that matches the title (first one only)
      if (skipTitle && (s.trim() === `## ${page.title}` || s.trim() === `# ${page.title}`)) {
        skipTitle = false;
        html += `<div class="ex-title">${esc(page.title)}</div>`;
        continue;
      }

      if (!s) {
        html += `<div class="ex-blank"></div>`;
        continue;
      }
      if (s.trim().startsWith("```")) continue;
      if (s.trim() === "---") {
        html += `<hr class="ex-hr">`;
        continue;
      }
      if (s.startsWith("## ")) {
        html += `<div class="ex-h2">${inlineFormat(s.slice(3))}</div>`;
        continue;
      }
      if (s.startsWith("### ")) {
        html += `<div class="ex-h3">${inlineFormat(s.slice(4))}</div>`;
        continue;
      }
      if (s.startsWith("#### ")) {
        html += `<div class="ex-h4">${inlineFormat(s.slice(5))}</div>`;
        continue;
      }
      if (s.startsWith("# ")) {
        html += `<div class="ex-title">${inlineFormat(s.slice(2))}</div>`;
        continue;
      }

      const trimmed = s.trimStart();
      if (trimmed.startsWith("- ") || trimmed.startsWith("* ")) {
        const indent = s.length - trimmed.length;
        const rest = trimmed.slice(2);
        html += `<div style="padding-left:${indent * 8 + 4}px">` +
          `<span class="ex-bullet">\u2022</span> ` +
          `<span class="ex-text">${inlineFormat(rest)}</span></div>`;
        continue;
      }

      html += `<div class="ex-text">${inlineFormat(s)}</div>`;
    }

    return html;
  }

  function inlineFormat(s) {
    let out = esc(s);
    out = out.replace(/\*\*([^*]+)\*\*/g, '<span class="ex-bold">$1</span>');
    out = out.replace(/`([^`]+)`/g, '<code class="ex-code">$1</code>');
    return out;
  }

  function esc(s) {
    return s
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  // ── Status bar ─────────────────────────────────────────────────────────
  function renderStatus() {
    const mode = focusPanel === "terminal" ? "shell" : "normal";
    const label = mode === "shell" ? "SHELL MODE" : "NORMAL MODE";
    const hint = mode === "shell"
      ? "Click panels to navigate"
      : "Click terminal to type commands";

    $statusLeft.innerHTML =
      `<span class="mode-badge ${mode}">[${label}]</span>` +
      `<span class="status-hint">${hint}</span>`;

    // Overall progress bar
    const total = content.missions.length;
    const done = content.missions.filter((m) => {
      const p = missionProgress(m);
      return p.done >= p.total && p.total > 0;
    }).length;
    const barLen = 10;
    const filled = Math.round(barLen * done / Math.max(1, total));
    $statusRight.innerHTML =
      `<span class="status-progress">` +
      `<span class="filled">${"\u2588".repeat(filled)}</span>` +
      `<span class="empty">${"\u2591".repeat(barLen - filled)}</span>` +
      `<span class="count">${done}/${total}</span>` +
      `</span>`;
  }

  // ── Focus management ───────────────────────────────────────────────────
  function setFocus(panel) {
    focusPanel = panel;
    renderStatus();

    // Visual feedback on panel headers and borders
    document.querySelectorAll(".panel").forEach((el) => {
      el.classList.remove("focused");
    });
    const activePanel = document.querySelector("." + panel + "-panel");
    if (activePanel) {
      activePanel.classList.add("focused");
    }

    document.querySelectorAll(".panel-header").forEach((el) => {
      el.style.background = "";
    });
    const headerCls = panel + "-header";
    const activeHeader = document.querySelector("." + headerCls);
    if (activeHeader) {
      activeHeader.style.background = "var(--surface0)";
    }
  }

  $missions.addEventListener("click", () => setFocus("missions"));
  $exercises.addEventListener("click", () => setFocus("exercises"));

  // ── Vertical resize handle ─────────────────────────────────────────────
  (function initResize() {
    let startY = 0, startH = 0;
    const exPanel = document.querySelector(".exercises-panel");
    const tmPanel = document.querySelector(".terminal-panel");

    $resize.addEventListener("mousedown", (e) => {
      e.preventDefault();
      startY = e.clientY;
      startH = tmPanel.offsetHeight;
      $resize.classList.add("active");

      function onMove(e2) {
        const delta = startY - e2.clientY;
        const newH = Math.max(80, startH + delta);
        tmPanel.style.height = newH + "px";
        tmPanel.style.flex = "none";
        fitAddon?.fit();
        sendResize();
      }

      function onUp() {
        $resize.classList.remove("active");
        document.removeEventListener("mousemove", onMove);
        document.removeEventListener("mouseup", onUp);
      }

      document.addEventListener("mousemove", onMove);
      document.addEventListener("mouseup", onUp);
    });
  })();

  // ── Keyboard shortcuts ─────────────────────────────────────────────────
  const $helpOverlay = document.getElementById("help-overlay");

  document.addEventListener("keydown", (e) => {
    // Help overlay: any key dismisses, ? toggles
    if ($helpOverlay && !$helpOverlay.hidden) {
      $helpOverlay.hidden = true;
      e.preventDefault();
      return;
    }

    // ? key toggles help overlay (from any panel)
    if (e.key === "?") {
      if ($helpOverlay) {
        $helpOverlay.hidden = !$helpOverlay.hidden;
        e.preventDefault();
      }
      return;
    }

    // Esc from terminal returns focus to nav
    if (e.key === "Escape" && focusPanel === "terminal") {
      setFocus("exercises");
      e.preventDefault();
      return;
    }

    // Only handle other shortcuts when not focused on terminal
    if (focusPanel === "terminal") return;

    const mission = content?.missions[missionIdx];
    if (!mission) return;

    if (e.key === "ArrowLeft" || e.key === "[") {
      if (pageIdx > 0) { pageIdx--; renderExercises(); }
      e.preventDefault();
    } else if (e.key === "ArrowRight" || e.key === "]") {
      if (pageIdx < mission.pages.length - 1) { pageIdx++; renderExercises(); }
      e.preventDefault();
    } else if (e.key === "j" || e.key === "ArrowDown") {
      if (focusPanel === "missions") {
        if (missionIdx < content.missions.length - 1) {
          missionIdx++;
          pageIdx = 0;
          renderMissions();
          renderExercises();
          renderStatus();
        }
      }
      e.preventDefault();
    } else if (e.key === "k" || e.key === "ArrowUp") {
      if (focusPanel === "missions") {
        if (missionIdx > 0) {
          missionIdx--;
          pageIdx = 0;
          renderMissions();
          renderExercises();
          renderStatus();
        }
      }
      e.preventDefault();
    } else if (e.key === "3" || e.key === "i") {
      term?.focus();
      e.preventDefault();
    }
  });

  // ── Grades persistence (localStorage) ──────────────────────────────────
  function loadGrades() {
    try {
      const raw = localStorage.getItem("terminal-gym-grades");
      if (raw) grades = JSON.parse(raw);
    } catch { /* ignore */ }
  }

  function saveGrades() {
    try {
      localStorage.setItem("terminal-gym-grades", JSON.stringify(grades));
    } catch { /* ignore */ }
  }

  // ── Flash message (toast notification) ────────────────────────────────
  let flashTimer = null;
  function flashMessage(text, ms = 3000) {
    const el = $exProgress;
    if (!el) return;
    const prev = el.innerHTML;
    el.innerHTML = '<span class="ex-bold" style="color: var(--yellow);">  ' + text + '</span>';
    clearTimeout(flashTimer);
    flashTimer = setTimeout(() => {
      el.innerHTML = prev;
      renderExercises();
    }, ms);
  }

  // ── Boot ───────────────────────────────────────────────────────────────
  loadGrades();
  loadContent().then(() => {
    initTerminal();
    setFocus("missions");
  });

})();
