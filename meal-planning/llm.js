// llm.js — LLM provider abstraction for meal plan generation
// Supports Anthropic (Claude) and OpenAI (ChatGPT)

// ── Model listing ────────────────────────────────────────────────────────────

async function fetchModels(provider, key) {
  if (provider === 'openai') {
    var resp = await fetch('https://api.openai.com/v1/models', {
      headers: { 'Authorization': 'Bearer ' + key }
    });
    if (!resp.ok) throw new Error('OpenAI API error ' + resp.status);
    var json = await resp.json();
    return json.data
      .map(function (m) { return m.id; })
      .filter(function (id) { return /^(gpt-|o1|o3|chatgpt-4)/.test(id); })
      .sort()
      .reverse();
  } else {
    var resp = await fetch('https://api.anthropic.com/v1/models', {
      headers: {
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-calls': 'true'
      }
    });
    if (!resp.ok) throw new Error('Anthropic API error ' + resp.status);
    var json = await resp.json();
    return json.data.map(function (m) { return m.id; }).reverse();
  }
}

var DEFAULT_MODELS = {
  anthropic: 'claude-opus-4-6',
  openai: 'gpt-4o'
};

// ── Prompt builder ──────────────────────────────────────────────────────────

function buildPrompt(weekKey, refinementNote) {
  var lockedMeals = getLockedMealsDescription(weekKey);
  var historyText = getRecentHistoryText(weekKey, 4);
  var recipesText = state.recipes.length > 0
    ? state.recipes.join('\n')
    : '(no recipes saved yet — suggest common meals)';

  var systemPrompt = [
    'You are a helpful meal planning assistant.',
    'Your job is to plan a week of meals (lunch, dinner, and snacks) for a family.',
    'Always respond with ONLY a valid JSON object — no markdown, no explanation.',
    'The JSON must have keys "0" through "6" (Monday=0, Sunday=6).',
    'Each day has keys: "breakfast", "lunch", "dinner", "snacks" (all strings).',
    'Use short meal names (2-5 words). Leave a field empty string "" if a meal is locked.'
  ].join(' ');

  var lines = [];
  lines.push('Plan meals for the week: ' + formatWeekLabel(weekKey));
  lines.push('');
  lines.push('RECIPE BOOK (draw from this list when possible):');
  lines.push(recipesText);
  lines.push('');
  lines.push('DIETARY PREFERENCES:');
  lines.push(state.preferences || '(none specified)');

  if (historyText) {
    lines.push('');
    lines.push('RECENT MEAL HISTORY (avoid repeating these):');
    lines.push(historyText);
  }

  if (lockedMeals) {
    lines.push('');
    lines.push('LOCKED MEALS (keep exactly as-is, copy them verbatim into the JSON):');
    lines.push(lockedMeals);
  }

  if (refinementNote && refinementNote.trim()) {
    lines.push('');
    lines.push('ADDITIONAL NOTE: ' + refinementNote.trim());
  }

  lines.push('');
  lines.push('Respond with ONLY the JSON object. Example:');
  lines.push('{"0":{"breakfast":"Oatmeal","lunch":"Pasta Bolognese","dinner":"Chicken Stir-fry","snacks":"Apple slices"},"1":{...},...,"6":{...}}');

  return { system: systemPrompt, user: lines.join('\n') };
}

function getLockedMealsDescription(weekKey) {
  var week = state.weeks[weekKey] || {};
  var lines = [];
  var days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  for (var d = 0; d < 7; d++) {
    var day = week[String(d)] || {};
    ['breakfast', 'lunch', 'dinner', 'snacks'].forEach(function (meal) {
      if (day[meal + 'Locked'] && day[meal]) {
        lines.push(days[d] + ' ' + meal + ': ' + day[meal]);
      }
    });
  }
  return lines.join('\n');
}

function getRecentHistoryText(currentWeekKey, numWeeks) {
  var keys = getPastWeekKeys(currentWeekKey, numWeeks);
  var days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  var sections = [];
  keys.forEach(function (key) {
    var week = state.weeks[key];
    if (!week) return;
    var meals = [];
    for (var d = 0; d < 7; d++) {
      var day = week[String(d)] || {};
      var parts = [day.lunch, day.dinner, day.snacks].filter(Boolean);
      if (parts.length) meals.push(days[d] + ': ' + parts.join(', '));
    }
    if (meals.length) sections.push('[' + key + ']\n' + meals.join('\n'));
  });
  return sections.join('\n\n');
}

// Returns up to n week keys before currentWeekKey, most recent first
function getPastWeekKeys(weekKey, n) {
  var keys = [];
  var k = weekKey;
  for (var i = 0; i < n; i++) {
    k = offsetWeek(k, -1);
    keys.push(k);
  }
  return keys;
}

// ── Provider dispatch ────────────────────────────────────────────────────────

async function callLLM(weekKey, refinementNote) {
  var prompt = buildPrompt(weekKey, refinementNote);
  var provider = state.settings.llmProvider || 'anthropic';
  var rawText;
  if (provider === 'openai') {
    rawText = await callOpenAI(prompt);
  } else {
    rawText = await callAnthropic(prompt);
  }
  return parseResponse(rawText);
}

// ── Anthropic ────────────────────────────────────────────────────────────────

async function callAnthropic(prompt) {
  var model = state.settings.llmModel || DEFAULT_MODELS.anthropic;
  var resp = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': state.settings.llmKey,
      'anthropic-version': '2023-06-01',
      'anthropic-dangerous-direct-browser-calls': 'true',
      'content-type': 'application/json'
    },
    body: JSON.stringify({
      model: model,
      max_tokens: 1024,
      system: prompt.system,
      messages: [{ role: 'user', content: prompt.user }]
    })
  });
  if (!resp.ok) {
    var err = await resp.text();
    throw new Error('Anthropic API error ' + resp.status + ': ' + err);
  }
  var json = await resp.json();
  return json.content[0].text;
}

// ── OpenAI ───────────────────────────────────────────────────────────────────

async function callOpenAI(prompt) {
  var model = state.settings.llmModel || DEFAULT_MODELS.openai;
  var resp = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + state.settings.llmKey,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: model,
      max_completion_tokens: 1024,
      messages: [
        { role: 'system', content: prompt.system },
        { role: 'user', content: prompt.user }
      ]
    })
  });
  if (!resp.ok) {
    var err = await resp.text();
    throw new Error('OpenAI API error ' + resp.status + ': ' + err);
  }
  var json = await resp.json();
  return json.choices[0].message.content;
}

// ── Response parser (shared) ─────────────────────────────────────────────────

function parseResponse(text) {
  // Strip markdown code fences if present
  var cleaned = text.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '').trim();
  // Find first { … } block in case there's preamble
  var start = cleaned.indexOf('{');
  var end = cleaned.lastIndexOf('}');
  if (start === -1 || end === -1) throw new Error('No JSON object found in LLM response');
  return JSON.parse(cleaned.slice(start, end + 1));
}
