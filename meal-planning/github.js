// github.js — read/write a JSON file in a GitHub repo via the Contents API
// Requires state.settings.githubPat, .githubRepo, .githubPath to be set.

var githubFileSha = null;  // SHA of last-known remote file; required for updates

function githubApiUrl() {
  var s = state.settings;
  return 'https://api.github.com/repos/' + s.githubRepo + '/contents/' + s.githubPath;
}

function githubHeaders() {
  return {
    'Authorization': 'Bearer ' + state.settings.githubPat,
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json'
  };
}

// Fetch remote data and merge into state. Returns true on success.
async function fetchFromGitHub() {
  if (!state.settings.githubPat || !state.settings.githubRepo || !state.settings.githubPath) {
    return false;
  }
  try {
    var resp = await fetch(githubApiUrl(), { headers: githubHeaders() });
    if (resp.status === 404) {
      // File doesn't exist yet — that's fine, we'll create it on first push
      githubFileSha = null;
      return true;
    }
    if (!resp.ok) return false;
    var json = await resp.json();
    githubFileSha = json.sha;
    var decoded = JSON.parse(atob(json.content.replace(/\n/g, '')));
    mergeRemoteData(decoded);
    return true;
  } catch (e) {
    return false;
  }
}

// Push current state to GitHub. Returns true on success.
async function pushToGitHub() {
  if (!state.settings.githubPat || !state.settings.githubRepo || !state.settings.githubPath) {
    return false;
  }
  try {
    var payload = buildRemotePayload();
    var encoded = btoa(unescape(encodeURIComponent(JSON.stringify(payload, null, 2))));
    var body = {
      message: 'chore: update meal plan data',
      content: encoded
    };
    if (githubFileSha) body.sha = githubFileSha;
    var resp = await fetch(githubApiUrl(), {
      method: 'PUT',
      headers: githubHeaders(),
      body: JSON.stringify(body)
    });
    if (!resp.ok) return false;
    var json = await resp.json();
    if (json.content && json.content.sha) githubFileSha = json.content.sha;
    return true;
  } catch (e) {
    return false;
  }
}

// What we store remotely: weeks + recipes only (not settings/keys)
function buildRemotePayload() {
  return {
    version: 1,
    weeks: state.weeks,
    recipes: state.recipes
  };
}

// Merge remote data into state, remote wins for weeks/recipes
function mergeRemoteData(remote) {
  if (!remote || remote.version !== 1) return;
  if (remote.weeks && typeof remote.weeks === 'object') {
    state.weeks = remote.weeks;
  }
  if (Array.isArray(remote.recipes)) {
    state.recipes = remote.recipes;
  }
}

// Debounced sync
var syncTimer = null;
function debouncedSync() {
  clearTimeout(syncTimer);
  syncTimer = setTimeout(async function () {
    showSyncBadge('syncing', 'Syncing…');
    var ok = await pushToGitHub();
    if (ok) {
      showSyncBadge('synced', 'Synced ✓');
    } else {
      showSyncBadge('error', 'Sync failed');
    }
  }, 1500);
}

function showSyncBadge(type, text) {
  var el = document.getElementById('syncBadge');
  if (!el) return;
  el.textContent = text;
  el.className = 'sync-badge show ' + type;
  if (type === 'synced') {
    setTimeout(function () { el.className = 'sync-badge'; }, 3000);
  }
}
