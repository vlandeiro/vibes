// app.js — main state, week arithmetic, rendering, and event handling

// ── State ────────────────────────────────────────────────────────────────────

var STORAGE_KEY = 'mealplanner_v1';

var state = {
  currentWeekKey: '',
  weeks: {},
  recipes: [],
  preferences: '- 5 servings of fruits and vegetables per day\n- Baby-friendly (1 year old)\n- Account for leftovers on some days\n- Avoid repeating meals across weeks\n- Balanced nutrition',
  settings: {
    llmProvider: 'anthropic',
    llmModel: 'claude-opus-4-6',
    llmKey: '',
    githubPat: '',
    githubRepo: 'vlandeiro/vibes',
    githubPath: 'meal-planning/data.json',
    mealTimes: {
      lunch:  { start: '12:00', end: '13:00' },
      dinner: { start: '18:00', end: '19:00' },
      snacks: { start: '15:00', end: '15:30' }
    }
  }
};

// ── LocalStorage ─────────────────────────────────────────────────────────────

function loadFromLocalStorage() {
  try {
    var raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return;
    var saved = JSON.parse(raw);
    if (saved.weeks)       state.weeks       = saved.weeks;
    if (saved.recipes)     state.recipes     = saved.recipes;
    if (saved.preferences) state.preferences = saved.preferences;
    if (saved.settings)    Object.assign(state.settings, saved.settings);
    if (saved.lastWeek)    state.currentWeekKey = saved.lastWeek;
  } catch (e) {}
}

function saveToLocalStorage() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({
      weeks:       state.weeks,
      recipes:     state.recipes,
      preferences: state.preferences,
      settings:    state.settings,
      lastWeek:    state.currentWeekKey
    }));
  } catch (e) {}
}

// ── Week arithmetic ───────────────────────────────────────────────────────────

// Returns ISO week string "YYYY-WNN" for the Monday of the week containing date
function getWeekKey(date) {
  // Find Monday of this week
  var d = new Date(date);
  var day = d.getDay(); // 0=Sun
  var diff = (day === 0) ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  d.setHours(0, 0, 0, 0);
  // ISO week number
  var jan4 = new Date(d.getFullYear(), 0, 4);
  var startOfWeek1 = new Date(jan4);
  startOfWeek1.setDate(jan4.getDate() - ((jan4.getDay() + 6) % 7));
  var weekNum = Math.round((d - startOfWeek1) / 604800000) + 1;
  var year = d.getFullYear();
  // Handle week 53 rolling into next year's week 1
  if (weekNum > 52) {
    var dec28 = new Date(year, 11, 28);
    if (d > dec28) { year++; weekNum = 1; }
  }
  return year + '-W' + String(weekNum).padStart(2, '0');
}

// Returns the Monday Date for a given "YYYY-WNN" key
function getMondayOfWeek(weekKey) {
  var parts = weekKey.split('-W');
  var year = parseInt(parts[0], 10);
  var week = parseInt(parts[1], 10);
  // Jan 4 is always in week 1
  var jan4 = new Date(year, 0, 4);
  var monday1 = new Date(jan4);
  monday1.setDate(jan4.getDate() - ((jan4.getDay() + 6) % 7));
  var result = new Date(monday1);
  result.setDate(monday1.getDate() + (week - 1) * 7);
  return result;
}

function offsetWeek(weekKey, delta) {
  var monday = getMondayOfWeek(weekKey);
  monday.setDate(monday.getDate() + delta * 7);
  return getWeekKey(monday);
}

function formatWeekLabel(weekKey) {
  var monday = getMondayOfWeek(weekKey);
  var sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);
  var opts = { month: 'short', day: 'numeric' };
  var start = monday.toLocaleDateString('en-US', opts);
  var end = sunday.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  return start + ' – ' + end;
}

function isToday(date) {
  var t = new Date();
  return date.getFullYear() === t.getFullYear() &&
         date.getMonth()    === t.getMonth() &&
         date.getDate()     === t.getDate();
}

function ensureWeek(weekKey) {
  if (!state.weeks[weekKey]) state.weeks[weekKey] = {};
  for (var d = 0; d < 7; d++) {
    var k = String(d);
    if (!state.weeks[weekKey][k]) {
      state.weeks[weekKey][k] = {
        lunch: '', dinner: '', snacks: '',
        lunchOut: false, dinnerOut: false, snacksOut: false,
        lunchLocked: false, dinnerLocked: false, snacksLocked: false
      };
    }
  }
}

// ── View switching ────────────────────────────────────────────────────────────

function switchView(name) {
  document.querySelectorAll('.view').forEach(function (el) {
    el.classList.toggle('active', el.id === 'view-' + name);
  });
  document.querySelectorAll('.nav-tab').forEach(function (el) {
    el.classList.toggle('active', el.dataset.view === name);
  });
  if (name === 'recipes') renderRecipes();
  if (name === 'settings') renderSettings();
}

// ── Planner rendering ─────────────────────────────────────────────────────────

var DAY_NAMES  = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
var MEALS      = ['lunch', 'dinner', 'snacks'];
var MEAL_LABELS = { lunch: 'Lunch', dinner: 'Dinner', snacks: 'Snacks' };
var MEAL_PLACEHOLDERS = { lunch: 'Add lunch…', dinner: 'Add dinner…', snacks: 'Add snacks…' };

function renderPlanner() {
  document.getElementById('weekLabel').textContent = formatWeekLabel(state.currentWeekKey);
  var grid = document.getElementById('weekGrid');
  grid.innerHTML = '';
  ensureWeek(state.currentWeekKey);
  var monday = getMondayOfWeek(state.currentWeekKey);
  for (var d = 0; d < 7; d++) {
    var date = new Date(monday);
    date.setDate(monday.getDate() + d);
    grid.appendChild(renderDayRow(d, date, state.weeks[state.currentWeekKey][String(d)]));
  }
}

function renderDayRow(dayIdx, date, dayData) {
  var row = document.createElement('div');
  row.className = 'day-row' + (isToday(date) ? ' is-today' : '');
  row.dataset.day = dayIdx;

  // Day label
  var label = document.createElement('div');
  label.className = 'day-label';
  label.innerHTML =
    '<span class="day-name">' + DAY_NAMES[dayIdx] + '</span>' +
    '<span class="day-date">' + date.getDate() + '</span>';
  row.appendChild(label);

  // Meal slots
  var slots = document.createElement('div');
  slots.className = 'meal-slots';

  MEALS.forEach(function (meal) {
    slots.appendChild(renderMealSlot(dayIdx, meal, dayData));
  });

  row.appendChild(slots);
  return row;
}

function renderMealSlot(dayIdx, meal, dayData) {
  var isLocked = !!dayData[meal + 'Locked'];
  var isOut    = !!dayData[meal + 'Out'];
  var text     = dayData[meal] || '';

  var slot = document.createElement('div');
  slot.className = 'meal-slot' + (isLocked ? ' is-locked' : '');
  slot.dataset.meal = meal;
  slot.dataset.day  = dayIdx;

  // Header: label + icons
  var header = document.createElement('div');
  header.className = 'meal-slot-header';

  var lbl = document.createElement('span');
  lbl.className = 'meal-slot-label';
  lbl.textContent = MEAL_LABELS[meal];
  header.appendChild(lbl);

  var icons = document.createElement('div');
  icons.className = 'slot-icons';

  var lockBtn = document.createElement('button');
  lockBtn.className = 'slot-icon-btn lock-btn' + (isLocked ? ' active' : '');
  lockBtn.title = isLocked ? 'Unlock' : 'Lock';
  lockBtn.textContent = '🔒';
  lockBtn.addEventListener('click', function (e) {
    e.stopPropagation();
    toggleLock(state.currentWeekKey, dayIdx, meal);
  });
  icons.appendChild(lockBtn);

  var outBtn = document.createElement('button');
  outBtn.className = 'slot-icon-btn out-btn' + (isOut ? ' active' : '');
  outBtn.title = isOut ? 'Remove Dining Out' : 'Mark as Dining Out';
  outBtn.textContent = '🍽️';
  outBtn.addEventListener('click', function (e) {
    e.stopPropagation();
    toggleDiningOut(state.currentWeekKey, dayIdx, meal);
  });
  icons.appendChild(outBtn);

  header.appendChild(icons);
  slot.appendChild(header);

  // Meal text (click to edit)
  var mealText = document.createElement('div');
  mealText.className = 'meal-text' + (isOut ? ' is-out' : '');
  mealText.dataset.placeholder = isOut ? 'Dining out' : MEAL_PLACEHOLDERS[meal];
  mealText.textContent = isOut ? (text || '') : text;
  mealText.addEventListener('click', function () {
    activateEdit(slot, dayIdx, meal);
  });
  slot.appendChild(mealText);

  return slot;
}

// ── Meal slot editing ─────────────────────────────────────────────────────────

function activateEdit(slotEl, dayIdx, meal) {
  // Prevent double-activating
  if (slotEl.querySelector('.meal-textarea')) return;

  var mealText = slotEl.querySelector('.meal-text');
  var currentVal = state.weeks[state.currentWeekKey][String(dayIdx)][meal] || '';

  var textarea = document.createElement('textarea');
  textarea.className = 'meal-textarea';
  textarea.value = currentVal;

  mealText.style.display = 'none';
  slotEl.appendChild(textarea);
  textarea.focus();

  function commit() {
    var val = textarea.value.trim();
    setMealValue(state.currentWeekKey, dayIdx, meal, val);
  }

  textarea.addEventListener('blur', function () {
    commit();
  });

  textarea.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      textarea.blur();
    }
    if (e.key === 'Escape') {
      // Restore without saving
      textarea.remove();
      mealText.style.display = '';
    }
  });
}

function setMealValue(weekKey, dayIdx, meal, val) {
  ensureWeek(weekKey);
  state.weeks[weekKey][String(dayIdx)][meal] = val;
  saveToLocalStorage();
  debouncedSync();
  // Re-render just this slot
  var slotEl = document.querySelector(
    '[data-day="' + dayIdx + '"] .meal-slot[data-meal="' + meal + '"]'
  );
  if (slotEl) {
    var newSlot = renderMealSlot(dayIdx, meal, state.weeks[weekKey][String(dayIdx)]);
    slotEl.replaceWith(newSlot);
  }
}

function toggleDiningOut(weekKey, dayIdx, meal) {
  ensureWeek(weekKey);
  var day = state.weeks[weekKey][String(dayIdx)];
  day[meal + 'Out'] = !day[meal + 'Out'];
  saveToLocalStorage();
  debouncedSync();
  refreshSlot(weekKey, dayIdx, meal);
}

function toggleLock(weekKey, dayIdx, meal) {
  ensureWeek(weekKey);
  var day = state.weeks[weekKey][String(dayIdx)];
  day[meal + 'Locked'] = !day[meal + 'Locked'];
  saveToLocalStorage();
  // No sync needed for lock state — it's UI preference only
  refreshSlot(weekKey, dayIdx, meal);
}

function refreshSlot(weekKey, dayIdx, meal) {
  var slotEl = document.querySelector(
    '.day-row[data-day="' + dayIdx + '"] .meal-slot[data-meal="' + meal + '"]'
  );
  if (slotEl) {
    var newSlot = renderMealSlot(dayIdx, meal, state.weeks[weekKey][String(dayIdx)]);
    slotEl.replaceWith(newSlot);
  }
}

// ── Recipes view ──────────────────────────────────────────────────────────────

function renderRecipes() {
  var list = document.getElementById('recipeList');
  var count = document.getElementById('recipeCount');
  count.textContent = state.recipes.length + ' recipe' + (state.recipes.length === 1 ? '' : 's');
  list.innerHTML = '';
  state.recipes.forEach(function (name, idx) {
    var item = document.createElement('div');
    item.className = 'recipe-item';
    var nameEl = document.createElement('span');
    nameEl.className = 'recipe-item-name';
    nameEl.textContent = name;
    var del = document.createElement('button');
    del.className = 'recipe-delete-btn';
    del.textContent = '×';
    del.title = 'Remove';
    del.addEventListener('click', function () {
      state.recipes.splice(idx, 1);
      saveToLocalStorage();
      debouncedSync();
      renderRecipes();
    });
    item.appendChild(nameEl);
    item.appendChild(del);
    list.appendChild(item);
  });
}

function parseAndSaveRecipes() {
  var raw = document.getElementById('recipePasteArea').value;
  var lines = raw.split('\n')
    .map(function (l) { return l.trim(); })
    .filter(function (l) { return l.length > 0; });
  // Merge with existing, deduplicate (case-insensitive)
  var existing = state.recipes.map(function (r) { return r.toLowerCase(); });
  lines.forEach(function (line) {
    if (existing.indexOf(line.toLowerCase()) === -1) {
      state.recipes.push(line);
      existing.push(line.toLowerCase());
    }
  });
  document.getElementById('recipePasteArea').value = '';
  saveToLocalStorage();
  debouncedSync();
  renderRecipes();
}

// ── Settings view ─────────────────────────────────────────────────────────────

function renderSettings() {
  var s = state.settings;
  document.getElementById('settingsProvider').value    = s.llmProvider || 'anthropic';
  document.getElementById('settingsModel').value       = s.llmModel || '';
  document.getElementById('settingsLlmKey').value      = s.llmKey || '';
  document.getElementById('settingsGithubPat').value   = s.githubPat || '';
  document.getElementById('settingsGithubRepo').value  = s.githubRepo || 'vlandeiro/vibes';
  document.getElementById('settingsGithubPath').value  = s.githubPath || 'meal-planning/data.json';
  document.getElementById('settingsPreferences').value = state.preferences || '';

  var mt = s.mealTimes || {};
  ['lunch', 'dinner', 'snacks'].forEach(function (meal) {
    var t = mt[meal] || {};
    var startEl = document.getElementById(meal + 'Start');
    var endEl   = document.getElementById(meal + 'End');
    if (startEl) startEl.value = t.start || '';
    if (endEl)   endEl.value   = t.end   || '';
  });

  // Update model placeholder based on provider
  updateModelPlaceholder();
}

function updateModelPlaceholder() {
  var provider = document.getElementById('settingsProvider').value;
  var modelInput = document.getElementById('settingsModel');
  modelInput.placeholder = provider === 'openai' ? 'gpt-4o' : 'claude-opus-4-6';
}

function saveSettings() {
  var s = state.settings;
  s.llmProvider  = document.getElementById('settingsProvider').value;
  s.llmModel     = document.getElementById('settingsModel').value.trim();
  s.llmKey       = document.getElementById('settingsLlmKey').value.trim();
  s.githubPat    = document.getElementById('settingsGithubPat').value.trim();
  s.githubRepo   = document.getElementById('settingsGithubRepo').value.trim();
  s.githubPath   = document.getElementById('settingsGithubPath').value.trim();
  state.preferences = document.getElementById('settingsPreferences').value;

  ['lunch', 'dinner', 'snacks'].forEach(function (meal) {
    s.mealTimes[meal] = {
      start: document.getElementById(meal + 'Start').value,
      end:   document.getElementById(meal + 'End').value
    };
  });

  saveToLocalStorage();

  var btn = document.getElementById('btnSaveSettings');
  var orig = btn.textContent;
  btn.textContent = 'Saved ✓';
  setTimeout(function () { btn.textContent = orig; }, 1500);
}

// ── LLM generation ────────────────────────────────────────────────────────────

async function generateWeek() {
  if (!state.settings.llmKey) {
    alert('Please add an API key in Settings first.');
    switchView('settings');
    return;
  }

  var note = document.getElementById('refinementInput').value;
  showLoading(true, 'Generating meal plan…');

  try {
    var weekJson = await callLLM(state.currentWeekKey, note);
    applyGeneratedWeek(weekJson);
    saveToLocalStorage();
    debouncedSync();
    renderPlanner();
  } catch (e) {
    alert('Generation failed: ' + e.message);
  } finally {
    showLoading(false);
  }
}

function applyGeneratedWeek(weekJson) {
  ensureWeek(state.currentWeekKey);
  for (var d = 0; d < 7; d++) {
    var key = String(d);
    var generated = weekJson[key] || weekJson[String(d)];
    if (!generated) continue;
    var existing = state.weeks[state.currentWeekKey][key];
    MEALS.forEach(function (meal) {
      if (!existing[meal + 'Locked'] && generated[meal] !== undefined) {
        existing[meal] = generated[meal];
      }
    });
  }
}

function showLoading(show, text) {
  var overlay = document.getElementById('loadingOverlay');
  var textEl  = document.getElementById('loadingText');
  if (text && textEl) textEl.textContent = text;
  overlay.classList.toggle('show', !!show);
}

// ── Init & event wiring ───────────────────────────────────────────────────────

async function init() {
  loadFromLocalStorage();

  if (!state.currentWeekKey) {
    state.currentWeekKey = getWeekKey(new Date());
  }

  ensureWeek(state.currentWeekKey);
  renderPlanner();

  // Try to load from GitHub
  if (state.settings.githubPat) {
    showSyncBadge('syncing', 'Syncing…');
    var ok = await fetchFromGitHub();
    if (ok) {
      showSyncBadge('synced', 'Synced ✓');
      renderPlanner();
      saveToLocalStorage();
    } else {
      showSyncBadge('error', 'Offline');
    }
  }

  // Nav tabs
  document.querySelectorAll('.nav-tab').forEach(function (tab) {
    tab.addEventListener('click', function () { switchView(tab.dataset.view); });
  });

  // Week navigation
  document.getElementById('btnPrevWeek').addEventListener('click', function () {
    state.currentWeekKey = offsetWeek(state.currentWeekKey, -1);
    ensureWeek(state.currentWeekKey);
    saveToLocalStorage();
    renderPlanner();
  });

  document.getElementById('btnNextWeek').addEventListener('click', function () {
    state.currentWeekKey = offsetWeek(state.currentWeekKey, 1);
    ensureWeek(state.currentWeekKey);
    saveToLocalStorage();
    renderPlanner();
  });

  document.getElementById('btnToday').addEventListener('click', function () {
    state.currentWeekKey = getWeekKey(new Date());
    ensureWeek(state.currentWeekKey);
    saveToLocalStorage();
    renderPlanner();
  });

  // Generate
  document.getElementById('btnGenerate').addEventListener('click', generateWeek);

  // Export
  document.getElementById('btnExport').addEventListener('click', function () {
    downloadICS(state.currentWeekKey);
  });

  // Recipes
  document.getElementById('btnParseRecipes').addEventListener('click', parseAndSaveRecipes);
  document.getElementById('btnClearRecipes').addEventListener('click', function () {
    if (confirm('Clear all recipes?')) {
      state.recipes = [];
      saveToLocalStorage();
      debouncedSync();
      renderRecipes();
    }
  });

  // Settings
  document.getElementById('settingsProvider').addEventListener('change', updateModelPlaceholder);
  document.getElementById('btnSaveSettings').addEventListener('click', saveSettings);
}

document.addEventListener('DOMContentLoaded', init);
