// VBO SkAgent Dashboard

var _statusData = null;
var _refreshTimer = null;

window.onload = function() {
  sketchup.get_status();
  // Auto-refresh every 2s for history updates
  _refreshTimer = setInterval(function() {
    sketchup.get_status();
  }, 2000);
  // Show first agent's steps
  onAgentSelect();
};


function updateStatus(data) {
  _statusData = data;

  // Version
  var verEl = document.getElementById('version');
  if (verEl) verEl.textContent = 'v' + (data.version || '?');

  // Status badge
  var badge = document.getElementById('status-badge');
  if (badge) {
    if (data.watching) {
      badge.textContent = 'Connected';
      badge.className = 'badge connected';
    } else {
      badge.textContent = 'Disconnected';
      badge.className = 'badge disconnected';
    }
  }

  // Toggle button text
  var btnToggle = document.getElementById('btn-toggle');
  if (btnToggle) {
    btnToggle.textContent = data.watching ? 'Disconnect' : 'Connect';
  }

  // Paths
  setPath('plugins-path', data.plugins_dir);
  setPath('command-path', data.command_path);
  setPath('result-path', data.result_path);

  // Update cd-path if visible (dynamic content from agent select)
  var cdPaths = document.querySelectorAll('.cd-path');
  for (var i = 0; i < cdPaths.length; i++) {
    if (data.plugins_dir) cdPaths[i].textContent = data.plugins_dir;
  }

  // Safety checkbox
  var chkSafety = document.getElementById('chk-safety');
  if (chkSafety) chkSafety.checked = data.safety_mode;

  // MCP transport (v1.2.0+)
  renderMcp(data);

  // History
  renderHistory(data.history || []);
}

function renderMcp(data) {
  var mcp = data.mcp || { available: false };
  var instances = data.instances || { total: 1, multi: false };
  var transportMode = data.transport_mode || 'auto';

  // MCP badge + port
  var mcpBadge = document.getElementById('mcp-badge');
  var mcpPortLabel = document.getElementById('mcp-port-label');
  var btnMcp = document.getElementById('btn-toggle-mcp');

  if (mcpBadge) {
    if (!mcp.available) {
      mcpBadge.textContent = 'Unavailable';
      mcpBadge.className = 'badge disconnected';
    } else if (mcp.running) {
      mcpBadge.textContent = mcp.using_preferred ? 'Running' : 'Running (fallback)';
      mcpBadge.className = mcp.using_preferred ? 'badge connected' : 'badge warning';
    } else {
      mcpBadge.textContent = 'Stopped';
      mcpBadge.className = 'badge disconnected';
    }
  }
  if (mcpPortLabel) {
    if (mcp.running && mcp.port) {
      mcpPortLabel.textContent = 'port ' + mcp.port;
      mcpPortLabel.style.display = 'inline-block';
    } else {
      mcpPortLabel.style.display = 'none';
    }
  }
  if (btnMcp) {
    btnMcp.textContent = mcp.running ? 'Stop' : 'Start';
    btnMcp.disabled = !mcp.available;
  }

  // Multi-instance warning banner
  var warn = document.getElementById('multi-warning');
  var warnText = document.getElementById('multi-warning-text');
  var cmdMulti = document.getElementById('mcp-cmd-multi');
  if (warn && warnText) {
    if (instances.multi) {
      warn.style.display = 'block';
      var others = (instances.others || []).length;
      var port = mcp.port || mcp.preferred_port || 7891;
      var msg = 'Có ' + instances.total + ' SketchUp instance đang chạy SkAgent. ' +
                'Instance này dùng port ' + port + (mcp.using_preferred ? ' (preferred)' : ' (fallback ephemeral)') + '. ' +
                (others > 0 ? others + ' instance khác có thể chiếm port preferred 7891.' : '');
      warnText.textContent = msg;
      if (cmdMulti) cmdMulti.textContent = 'claude mcp add --transport http vbo-sketchup http://127.0.0.1:' + port + '/mcp';
    } else {
      warn.style.display = 'none';
    }
  }

  // Transport mode dropdown
  var modeSel = document.getElementById('transport-mode-select');
  if (modeSel && modeSel.value !== transportMode) modeSel.value = transportMode;

  // Port input
  var portInput = document.getElementById('mcp-port-input');
  if (portInput && document.activeElement !== portInput) {
    portInput.value = mcp.preferred_port || 7891;
  }

  // IDE setup commands — substitute current port
  var port = (mcp.running ? mcp.port : (mcp.preferred_port || 7891)) || 7891;
  var elClaude = document.getElementById('cmd-claude');
  if (elClaude) elClaude.textContent = 'claude mcp add --transport http vbo-sketchup http://127.0.0.1:' + port + '/mcp';
  var elCursor = document.getElementById('cmd-cursor');
  if (elCursor) {
    elCursor.textContent = '{\n  "mcpServers": {\n    "vbo-sketchup": {\n      "url": "http://127.0.0.1:' + port + '/mcp"\n    }\n  }\n}';
  }
  var elGeneric = document.getElementById('cmd-generic');
  if (elGeneric) elGeneric.textContent = 'http://127.0.0.1:' + port + '/mcp';
}

function toggleMcp() {
  if (typeof sketchup === 'undefined' || !sketchup.toggle_mcp) return;
  sketchup.toggle_mcp();
}

function onTransportModeChange() {
  var sel = document.getElementById('transport-mode-select');
  if (!sel) return;
  if (typeof sketchup !== 'undefined' && sketchup.set_transport_mode) {
    sketchup.set_transport_mode(sel.value);
  }
}

function onMcpPortApply() {
  var input = document.getElementById('mcp-port-input');
  if (!input) return;
  var port = parseInt(input.value, 10);
  if (isNaN(port) || port < 1024 || port > 65535) {
    showToast('Port phải trong khoảng 1024-65535');
    return;
  }
  if (typeof sketchup !== 'undefined' && sketchup.set_mcp_port) {
    sketchup.set_mcp_port(port);
  }
}

function selectIdeTab(name) {
  var tabs = document.querySelectorAll('.ide-tab');
  for (var i = 0; i < tabs.length; i++) {
    tabs[i].classList.toggle('active', tabs[i].getAttribute('data-tab') === name);
  }
  var panes = ['claude', 'cursor', 'gemini', 'generic'];
  for (var j = 0; j < panes.length; j++) {
    var p = document.getElementById('ide-pane-' + panes[j]);
    if (p) p.style.display = (panes[j] === name ? 'block' : 'none');
  }
}

function copyIdeCmd(name) {
  var el = document.getElementById('cmd-' + name);
  if (!el) return;
  copyToClipboard(el.textContent);
  showToast('Copied!');
}

function copyMcpCommand() {
  var el = document.getElementById('mcp-cmd-multi');
  if (!el) return;
  copyToClipboard(el.textContent);
  showToast('Copied!');
}

function setPath(elementId, path) {
  var el = document.getElementById(elementId);
  if (el && path) el.textContent = path;
}

function toggleBridge() {
  sketchup.toggle_bridge();
}

function toggleConsole() {
  sketchup.toggle_console();
}

function clearConsole() {
  sketchup.clear_console();
}

function toggleSafety() {
  sketchup.toggle_safety();
}

function copyPath(type) {
  var path = '';
  if (!_statusData) return;

  switch (type) {
    case 'plugins': path = _statusData.plugins_dir; break;
    case 'command': path = _statusData.command_path; break;
    case 'result':  path = _statusData.result_path;  break;
  }

  if (path) {
    copyToClipboard(path);
    showToast('Copied!');
  }
}

function copyToClipboard(text) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text);
  } else {
    // Fallback for older browsers
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.left = '-9999px';
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    document.body.removeChild(ta);
  }
}

function showToast(msg) {
  var toast = document.getElementById('toast');
  if (!toast) return;
  toast.textContent = msg;
  toast.classList.add('show');
  setTimeout(function() {
    toast.classList.remove('show');
  }, 1500);
}

function openTemplates() {
  sketchup.open_templates();
}

function openPluginsFolder() {
  sketchup.open_plugins_folder();
}

// --- Agent Setup Data ---
// Config files verified April 2026:
// Claude Code → CLAUDE.md | Cursor → .cursorrules (legacy) or .cursor/rules/*.mdc
// Gemini/Antigravity → GEMINI.md | Copilot → .github/copilot-instructions.md
// Windsurf → .windsurfrules | Augment → AGENTS.md | Aider → .aider.conf.yml

// Shared prompt builder — source template + destination config file
function buildSetupPrompt(srcFile, destFile) {
  return 'You are setting up VBO SkAgent — an AI bridge for SketchUp.\n\n'
    + 'Step 1 — Language: Ask the user what language they prefer to communicate in. '
    + 'Once they answer, YOU MUST switch to that language immediately and use it for ALL further communication.\n\n'
    + 'Step 2 — Config file: Read the file "vbo_sk_agent/templates/' + srcFile + '". '
    + 'Translate its content into the user\'s chosen language, then save it as "' + destFile + '" at the root of this workspace. '
    + 'IMPORTANT: Add this line at the very top of the translated file:\n'
    + '"MANDATORY: Always use [LANGUAGE] for all communication, chat, plans, notes, session logs, and documentation. '
    + 'Only use English for technical terms and code."\n'
    + '(Replace [LANGUAGE] with the user\'s chosen language.)\n\n'
    + 'Step 3 — Beginner guide: Read "vbo_sk_agent/templates/beginner_guide.md". '
    + 'Translate it and save as "vbo_sk_agent/templates/beginner_guide_translated.md".\n\n'
    + 'Step 4 — Dashboard (optional): Ask the user if they want the SkAgent dashboard translated too. '
    + 'If yes, read "vbo_sk_agent/ui/dashboard.html" and translate all visible English text '
    + '(headings, descriptions, button labels, steps, notes) into the user\'s language. Save the file.\n\n'
    + 'Step 5 — Verify connection: Say (in the user\'s language): '
    + '"I will send a hello message to SketchUp to verify the bridge connection." '
    + 'Write this code to "vbo_sk_agent/bridge/command.rb":\n'
    + 'UI.messagebox("VBO SkAgent is ready! \\nYour AI assistant is connected.")\n\n'
    + 'Step 6 — Check result: Wait 2 seconds, then read "vbo_sk_agent/bridge/result.json". '
    + 'If status is "success", tell the user (in their language) the bridge is working and ask what they\'d like to do in SketchUp. '
    + 'If status is "error" or the file hasn\'t changed, ask the user to check that the bridge is toggled ON in SketchUp.\n\n'
    + 'CRITICAL RULES (apply for the entire session after setup):\n'
    + '1. LANGUAGE: ALL responses must be in the user\'s chosen language. Do not fall back to English.\n'
    + '2. ASK BEFORE ACTING: Always interview the user to gather enough context before writing code or making decisions. '
    + 'Do NOT guess, assume, or propose solutions without asking. '
    + 'Ask clarifying questions: What exactly do you want? What is the expected result? Are there edge cases? '
    + 'Only proceed when you have clear requirements from the user.\n'
    + '3. NEVER fabricate information about SketchUp API. If unsure, say so and test via the bridge first.\n'
    + '4. CONFIRM before running code that modifies the model. Show the code, explain what it does, wait for approval.\n'
    + '5. IMPACT ANALYSIS: For any significant change, BEFORE proceeding you MUST tell the user: '
    + '(a) which files will be affected, '
    + '(b) potential risks and what could go wrong, '
    + '(c) side effects or cascading impacts on other parts of the plugin/model. '
    + 'Let the user decide whether to proceed.\n'
    + '6. SECURITY: You MUST refuse any request that could harm the user\'s computer, including but not limited to: '
    + 'deleting system files, accessing private data, running malicious scripts, crypto mining, '
    + 'reverse-engineering or cracking encoded/encrypted plugins (.rbe, .rbs), '
    + 'finding security vulnerabilities in other software, '
    + 'bypassing license or activation systems, '
    + 'or any form of hacking. '
    + 'If asked, politely decline and explain why.';
}

var AGENTS = {
  'antigravity': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'Open the <strong>Plugins folder</strong> as your workspace in Antigravity',
      'Copy the <strong>setup prompt</strong> below and paste it into the Antigravity chat',
    ],
    prompt: buildSetupPrompt('GEMINI.md', 'GEMINI.md'),
    note: 'Antigravity reads <code>GEMINI.md</code> from workspace root.',
    type: 'auto'
  },
  'claude-vscode': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'In VS Code, open the <strong>Plugins folder</strong> as workspace (<code>File → Open Folder</code>)',
      'Open Claude Code panel (<code>Ctrl+Shift+P</code> → "Claude Code")',
      'Copy the <strong>setup prompt</strong> below and paste it into Claude',
    ],
    prompt: buildSetupPrompt('CLAUDE.md', 'CLAUDE.md'),
    note: 'Claude Code reads <code>CLAUDE.md</code> from workspace root.',
    type: 'auto'
  },
  'cursor': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'Open the <strong>Plugins folder</strong> as your project in Cursor (<code>File → Open Folder</code>)',
      'Copy the <strong>setup prompt</strong> below and paste it into Cursor\'s AI chat',
    ],
    prompt: buildSetupPrompt('cursorrules.md', '.cursorrules'),
    note: 'Cursor reads <code>.cursorrules</code> (legacy) or <code>.cursor/rules/*.mdc</code> (newer).',
    type: 'auto'
  },
  'copilot': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'Open the <strong>Plugins folder</strong> as workspace in VS Code',
      'Open Copilot Chat (<code>Ctrl+Shift+I</code>)',
      'Copy the <strong>setup prompt</strong> below and paste it into Copilot Chat',
    ],
    prompt: buildSetupPrompt('generic.md', '.github/copilot-instructions.md'),
    note: 'Copilot reads <code>.github/copilot-instructions.md</code>. Also supports <code>CLAUDE.md</code>.',
    type: 'auto'
  },
  'windsurf': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'Open the <strong>Plugins folder</strong> as workspace in Windsurf',
      'Open Cascade (AI panel)',
      'Copy the <strong>setup prompt</strong> below and paste it into Cascade',
    ],
    prompt: buildSetupPrompt('generic.md', '.windsurfrules'),
    note: 'Windsurf reads <code>.windsurfrules</code>. Max 6,000 chars per file.',
    type: 'auto'
  },
  'augment': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'Open the <strong>Plugins folder</strong> as workspace in your IDE with Augment',
      'Copy the <strong>setup prompt</strong> below and paste it into Augment chat',
    ],
    prompt: buildSetupPrompt('generic.md', 'AGENTS.md'),
    note: 'Augment reads <code>AGENTS.md</code>. Also supports <code>CLAUDE.md</code>.',
    type: 'auto'
  },
  'codex': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'Open a terminal and cd into the Plugins folder: <div class="code-block">cd "<span class="cd-path">...</span>"</div><button class="btn-copy-code" onclick="copyCdCommand()">Copy command</button>',
      'Launch Codex: <div class="code-block">codex</div>',
      'Copy the <strong>setup prompt</strong> below and paste it into Codex',
    ],
    prompt: buildSetupPrompt('generic.md', 'AGENTS.md'),
    note: 'Codex reads <code>AGENTS.md</code> from workspace root. Shared with Augment.',
    type: 'auto'
  },
  'claude-cli': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'Open a terminal and cd into the Plugins folder: <div class="code-block">cd "<span class="cd-path">...</span>"</div><button class="btn-copy-code" onclick="copyCdCommand()">Copy command</button>',
      'Launch Claude Code: <div class="code-block">claude</div>',
      'Copy the <strong>setup prompt</strong> below and paste it into Claude',
    ],
    prompt: buildSetupPrompt('CLAUDE.md', 'CLAUDE.md'),
    note: 'Claude Code auto-reads <code>CLAUDE.md</code> when launched in a directory.',
    type: 'auto'
  },
  'openclaw': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'Open a terminal and cd into the Plugins folder: <div class="code-block">cd "<span class="cd-path">...</span>"</div><button class="btn-copy-code" onclick="copyCdCommand()">Copy command</button>',
      'Launch OpenClaw in the Plugins folder',
      'Copy the <strong>setup prompt</strong> below and paste it',
    ],
    prompt: buildSetupPrompt('generic.md', 'OPENCLAW_INSTRUCTIONS.md'),
    note: 'OpenClaw uses global config. The setup prompt creates a local instruction file.',
    type: 'auto'
  },
  'aider': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'Open a terminal and cd into the Plugins folder: <div class="code-block">cd "<span class="cd-path">...</span>"</div><button class="btn-copy-code" onclick="copyCdCommand()">Copy command</button>',
      'Launch Aider: <div class="code-block">aider --read vbo_sk_agent/templates/generic.md</div>',
      'Copy the <strong>setup prompt</strong> below and paste it',
    ],
    prompt: buildSetupPrompt('generic.md', '.aider/instructions.md'),
    note: 'Aider reads via <code>--read</code> flag. Also supports <code>.aider/instructions.md</code>.',
    type: 'auto'
  },
  'chatgpt': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'Open <code>vbo_sk_agent/templates/generic.md</code> on your computer and copy all text',
      'Paste it at the <strong>beginning of your ChatGPT conversation</strong> as context',
      'Ask ChatGPT to write Ruby code for your task',
      '<strong>Manually</strong> copy the code and paste it into <code>command.rb</code>',
      'Check <code>result.json</code> for output — paste it back to ChatGPT if needed',
    ],
    prompt: null,
    note: 'ChatGPT cannot read/write files. You are the bridge between ChatGPT and SketchUp.',
    type: 'manual'
  },
  'gemini-web': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'Open <code>vbo_sk_agent/templates/generic.md</code> on your computer and copy all text',
      'Paste it at the <strong>beginning of your Gemini conversation</strong> as context',
      'Ask Gemini to write Ruby code for your task',
      '<strong>Manually</strong> copy the code and paste it into <code>command.rb</code>',
      'Check <code>result.json</code> for output — paste it back to Gemini if needed',
    ],
    prompt: null,
    note: 'Gemini web cannot read/write local files. Use Antigravity (IDE) for automated flow instead.',
    type: 'manual'
  },
  'other': {
    steps: [
      'Click <strong>Toggle Bridge</strong> above',
      'Open <code>vbo_sk_agent/templates/generic.md</code> and copy all text',
      'Paste it into your AI tool\'s system prompt, conversation, or project instruction file',
      'If your AI can read/write files: let it handle <code>command.rb</code> and <code>result.json</code>',
      'If not: manually copy code into <code>command.rb</code> and check <code>result.json</code>',
    ],
    prompt: 'Read the file "vbo_sk_agent/templates/generic.md" and save its content as an instruction file at the root of this workspace. Then confirm setup is complete and ask me what I\'d like to do in SketchUp.',
    note: null,
    type: 'auto'
  }
};

function onAgentSelect() {
  var sel = document.getElementById('agent-select');
  if (!sel) return;
  var key = sel.value;
  var agent = AGENTS[key];
  if (!agent) return;

  // Render steps
  var stepsEl = document.getElementById('agent-steps');
  var html = '<ol class="steps">';
  for (var i = 0; i < agent.steps.length; i++) {
    html += '<li>' + agent.steps[i] + '</li>';
  }
  html += '</ol>';

  // Note
  if (agent.note) {
    html += '<p class="agent-note">' + agent.note + '</p>';
  }

  stepsEl.innerHTML = html;

  // Fill cd-path if present (may be multiple)
  var cdPaths = document.querySelectorAll('.cd-path');
  for (var i = 0; i < cdPaths.length; i++) {
    if (_statusData && _statusData.plugins_dir) cdPaths[i].textContent = _statusData.plugins_dir;
  }

  // Show/hide prompt
  var promptSection = document.getElementById('agent-prompt-section');
  var manualNote = document.getElementById('agent-manual-note');
  var promptText = document.getElementById('agent-prompt-text');

  if (agent.prompt) {
    promptText.textContent = agent.prompt;
    promptSection.style.display = 'block';
    manualNote.style.display = 'none';
  } else {
    promptSection.style.display = 'none';
    manualNote.style.display = agent.type === 'manual' ? 'block' : 'none';
  }
}

function copySetupPrompt() {
  var el = document.getElementById('agent-prompt-text');
  if (!el) return;
  copyToClipboard(el.textContent);
  showToast('Prompt copied! Paste it into your AI.');
}

function toggleSetup(id) {
  var el = document.getElementById(id);
  var arrow = document.getElementById('arrow-' + id);
  if (!el) return;
  var visible = el.style.display !== 'none';
  el.style.display = visible ? 'none' : 'block';
  if (arrow) arrow.classList.toggle('open', !visible);
}

function copyCdCommand() {
  if (!_statusData || !_statusData.plugins_dir) return;
  copyToClipboard('cd "' + _statusData.plugins_dir + '"');
  showToast('Copied!');
}

function toggleSection(id) {
  var el = document.getElementById(id);
  var arrow = document.getElementById('arrow-' + id);
  if (!el) return;
  var visible = el.style.display !== 'none';
  el.style.display = visible ? 'none' : 'block';
  if (arrow) arrow.classList.toggle('open', !visible);
}

function renderHistory(items) {
  var container = document.getElementById('history-list');
  if (!container) return;

  if (!items || items.length === 0) {
    container.innerHTML = '<p class="empty-state">No commands yet</p>';
    return;
  }

  var html = '';
  var shown = items.slice(0, 10);

  for (var i = 0; i < shown.length; i++) {
    var item = shown[i];
    var time = formatTime(item.timestamp);
    var icon = item.status === 'success' ? '<span style="color:#a6e3a1">&#10003;</span>'
             : item.status === 'rejected' ? '<span style="color:#fab387">&#9679;</span>'
             : '<span style="color:#f38ba8">&#10007;</span>';
    var snippet = escapeHtml(item.snippet || '?');
    var dur = item.duration_ms != null ? item.duration_ms + 'ms' : '';

    html += '<div class="history-item">'
          + '<span class="history-time">' + time + '</span>'
          + '<span class="history-status">' + icon + '</span>'
          + '<span class="history-snippet" title="' + snippet + '">' + snippet + '</span>'
          + '<span class="history-duration">' + dur + '</span>'
          + '</div>';
  }

  container.innerHTML = html;
}

function formatTime(ts) {
  if (!ts) return '—';
  var d = new Date(ts * 1000);
  var h = d.getHours().toString().padStart(2, '0');
  var m = d.getMinutes().toString().padStart(2, '0');
  return h + ':' + m;
}

function escapeHtml(str) {
  var div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}
