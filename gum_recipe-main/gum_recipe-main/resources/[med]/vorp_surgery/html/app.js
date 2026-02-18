const resourceName = window.GetParentResourceName ? GetParentResourceName() : 'vorp_surgery';
const app = document.getElementById('app');
const tools = document.getElementById('tools');
const statusLabel = document.getElementById('status');
const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');

const TOOL_LIST = ['select_zone', 'scalpel', 'retractors', 'forceps', 'clamps', 'sutures', 'antiseptic'];
let selectedTool = 'select_zone';
let selectedZone = null;
let drawing = false;
let actions = [];
let errors = 0;
let pointsPlaced = 0;

function post(name, body) {
  return fetch(`https://${resourceName}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body || {})
  });
}

function setStatus(text) {
  statusLabel.textContent = text;
}

function resetState() {
  actions = [];
  errors = 0;
  pointsPlaced = 0;
  selectedTool = 'select_zone';
  selectedZone = null;
  drawing = false;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
}

function logAction(tool, extra = {}) {
  actions.push({ t: Date.now(), tool, zone: selectedZone, ...extra });
}

function renderTools(hotkeys = {}) {
  tools.innerHTML = '';
  TOOL_LIST.forEach((toolName, index) => {
    const btn = document.createElement('button');
    btn.className = 'tool';
    if (toolName === selectedTool) btn.classList.add('active');
    const hk = hotkeys[index + 1] ? ` [${index + 1}]` : '';
    btn.textContent = `${toolName}${hk}`;
    btn.onclick = () => {
      selectedTool = toolName;
      renderTools(hotkeys);
    };
    tools.appendChild(btn);
  });
}

window.addEventListener('message', (event) => {
  const { action, payload } = event.data || {};
  if (action === 'show') {
    app.classList.remove('hidden');
    resetState();
    renderTools(payload?.hotkeys || {});
    setStatus('Choisir une zone puis inciser précisément.');
  } else if (action === 'hide') {
    app.classList.add('hidden');
  }
});

document.querySelectorAll('#zones button').forEach((btn) => {
  btn.addEventListener('click', () => {
    selectedZone = btn.dataset.zone;
    logAction('select_zone', { zone: selectedZone });
    setStatus(`Zone sélectionnée: ${selectedZone}`);
  });
});

canvas.addEventListener('mousedown', (e) => {
  if (!selectedZone) {
    errors += 1;
    setStatus('Erreur: sélectionner une zone d\'abord.');
    return;
  }

  drawing = true;
  const rect = canvas.getBoundingClientRect();
  const x = (e.clientX - rect.left) * (canvas.width / rect.width);
  const y = (e.clientY - rect.top) * (canvas.height / rect.height);

  if (selectedTool === 'scalpel') {
    logAction('incision', { x, y });
    ctx.strokeStyle = '#f87171';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x, y);
  } else if (selectedTool === 'sutures') {
    pointsPlaced += 1;
    logAction('sutures', { x, y, point: pointsPlaced });
    ctx.fillStyle = '#fde047';
    ctx.fillRect(x - 2, y - 2, 4, 4);
  } else {
    logAction(selectedTool, { x, y });
  }
});

canvas.addEventListener('mousemove', (e) => {
  if (!drawing || selectedTool !== 'scalpel') return;
  const rect = canvas.getBoundingClientRect();
  const x = (e.clientX - rect.left) * (canvas.width / rect.width);
  const y = (e.clientY - rect.top) * (canvas.height / rect.height);
  ctx.lineTo(x, y);
  ctx.stroke();
});

canvas.addEventListener('mouseup', () => {
  drawing = false;
});

canvas.addEventListener('mouseleave', () => {
  drawing = false;
});

document.getElementById('cancel').addEventListener('click', () => {
  post('cancel', { reason: 'manual_cancel' });
});

document.getElementById('finish').addEventListener('click', () => {
  const precision = Math.max(0, Math.min(1, 0.4 + (pointsPlaced >= 4 ? 0.25 : 0) - errors * 0.05));
  post('complete', { actions, errors, precision });
});

window.addEventListener('keydown', (e) => {
  const parsed = Number(e.key);
  if (Number.isNaN(parsed) || parsed < 1 || parsed > TOOL_LIST.length) return;
  selectedTool = TOOL_LIST[parsed - 1];
  renderTools({});
});
