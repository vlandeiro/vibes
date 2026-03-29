--[[
  whisper.lua — Speech-to-text via local Whisper + Ollama
  --------------------------------------------------------
--]]

local config = {
  -- Hotkeys
  hotkey_toggle    = { mods = {"cmd", "alt"},         key = "R" },
  hotkey_stop_copy = { mods = {"cmd", "alt", "shift"}, key = "R" },
  hotkey_cancel    = { mods = {"shift"},               key = "Escape" },

  -- Binary paths
  sox    = "/opt/homebrew/bin/sox",
  curl   = "/usr/bin/curl",

  -- Temp files
  recording_file = "/tmp/whisper_recording.wav",
  meter_raw_file = "/tmp/whisper_meter.raw",

  -- Audio processing
  whisper_url   = "http://127.0.0.1:49440/inference",
  whisper_model = "large-v3-turbo",
  ollama_url    = "http://localhost:49450/api/generate",
  ollama_model  = "qwen3.5:9b",
  ollama_num_ctx = 1024,

  -- Visual Meter Configuration
  meter_sensitivity = 80,   -- Increase if bars are too small (e.g., 300, 400)
  meter_noise_gate  = 0.005, -- Increase if bars move when you aren't talking (e.g., 0.01)

  -- Modes Configuration
  modes = {
    raw = {
      title = "􀑃 Raw (Unfiltered)", -- Icon: waveform.path
    },
    casual = {
      title = "􀒤 Polished Casual (Default)", -- Icon: bubble.left.and.bubble.right
      system_en = "You are a transcription cleaner. Remove only these specific artifacts: filler words (um, uh, like, you know, so, well, I mean, right), false starts where the speaker restarts a sentence, and immediately repeated words. Fix obvious speech-to-text mishearings and add punctuation. Preserve the speaker's original wording, sentence structure, and vocabulary — do not rephrase, reorder, summarize, or improve anything. When in doubt, keep the word. Return only the cleaned text.",
      system_fr = "Tu es un nettoyeur de transcriptions. Supprime uniquement ces artefacts spécifiques : mots de remplissage (euh, ben, genre, voilà, donc, enfin, quoi, hein), faux départs où le locuteur recommence une phrase, et mots immédiatement répétés. Corrige les erreurs évidentes de reconnaissance vocale et ajoute la ponctuation. Préserve le vocabulaire, la structure des phrases et les choix de mots du locuteur — ne reformule, ne réordonne, ne résume et n'améliore rien. En cas de doute, garde le mot. Retourne uniquement le texte nettoyé."
    },
    tech = {
      title = "􀙚 Tech & Markdown", -- Icon: chevron.left.forwardslash.chevron.right
      system_en = "Clean up the transcription as a single Markdown paragraph. Capitalize technical terms correctly (e.g., JavaScript, PostgreSQL, macOS, TypeScript, Redis, Kubernetes). Wrap inline code, function names, CLI commands, and file paths in backticks. Remove filler words and fix transcription errors. Do not add headings, bullet points, or restructure the text. Return only the Markdown text.",
      system_fr = "Nettoie la transcription en un seul paragraphe Markdown. Mets correctement en majuscules les termes techniques (ex. : JavaScript, PostgreSQL, macOS, TypeScript, Redis, Kubernetes). Entoure le code en ligne, les noms de fonctions, les commandes CLI et les chemins de fichiers avec des backticks. Supprime les mots de remplissage et corrige les erreurs de transcription. N'ajoute pas de titres, de listes à puces et ne restructure pas le texte. Retourne uniquement le texte Markdown."
    },
    translate = {
      title = "􀄐 Cross-Translator", -- Icon: arrow.left.arrow.right.square
      system_en = "Translate the transcription between French and English. If the text is primarily in French (even with some English words mixed in), translate everything into natural, conversational English. If the text is in English, translate it into natural, conversational French. Match the formality level of the original. Fix any transcription errors and remove filler words. Return only the translated text.",
      system_fr = "Traduis la transcription entre le français et l'anglais. Si le texte est principalement en français (même avec quelques mots anglais), traduis tout en anglais naturel et conversationnel. Si le texte est en anglais, traduis-le en français naturel et conversationnel. Respecte le niveau de formalité de l'original. Corrige les erreurs de transcription et supprime les mots de remplissage. Retourne uniquement le texte traduit."
    },
    notes = {
      title = "􀼏 Structured Notes", -- Icon: list.bullet.clipboard
      system_en = "You are an executive assistant. Turn the transcription into a flat list of bullet points, one per distinct idea or action item. Use concise, complete sentences. Remove filler words and conversational fluff. Do not add headings, sub-bullets, numbering, or commentary. Return only the bulleted list.",
      system_fr = "Tu es un assistant de direction. Transforme la transcription en une liste à puces plate, une par idée distincte ou action à réaliser. Utilise des phrases concises et complètes. Supprime les mots de remplissage et le bla-bla conversationnel. N'ajoute pas de titres, de sous-puces, de numérotation ou de commentaires. Retourne uniquement la liste à puces."
    },
    email = {
      title = "􀍕 Professional Email", -- Icon: envelope
      system_en = "You are an executive assistant. Transform the dictation into a professional email. Start with a casual greeting (Hello, Hi) and end with a casual closing (Best, Thanks, Cheers). Keep the tone clear and polite but not overly formal. Fix transcription errors and remove filler words. Add paragraph breaks between distinct topics. Do not add a subject line. Return only the email text.",
      system_fr = "Tu es un assistant de direction. Transforme la dictée en un e-mail professionnel. Commence par une salutation décontractée (Bonjour, Salut) et termine par une formule de politesse légère (Cordialement, Merci, Bonne journée). Garde un ton clair et poli mais pas trop formel. Corrige les erreurs de transcription et supprime les mots de remplissage. Ajoute des sauts de paragraphe entre les sujets distincts. N'ajoute pas de ligne d'objet. Retourne uniquement le texte de l'e-mail."
    },
    message = {
      title = "􀈟 Quick Message (Slack/Text)", -- Icon: paperplane
      system_en = "Transform the transcription into a message suitable for Slack or text. Use a casual, natural tone — write like a real person, not an assistant. Remove filler words and fix transcription errors. Do not add greetings, sign-offs, or formatting unless the speaker explicitly included them. Return only the message text.",
      system_fr = "Transforme la transcription en un message adapté pour Slack ou SMS. Utilise un ton décontracté et naturel — écris comme une vraie personne, pas comme un assistant. Supprime les mots de remplissage et corrige les erreurs de transcription. N'ajoute pas de salutations, de formules de politesse ou de mise en forme sauf si le locuteur les a explicitement inclus. Retourne uniquement le texte du message."
    }
  },

  -- Logging and files
  history_file      = os.getenv("HOME") .. "/.hammerspoon/whisper_history.json",
  error_log_file    = os.getenv("HOME") .. "/.hammerspoon/whisper_error.log",
  custom_words_file = os.getenv("HOME") .. "/.hammerspoon/whisper_words.txt",

  emacs_app_name      = "Emacs",
  emacsclient         = "/opt/homebrew/bin/emacsclient",
  emacs_project_file  = "/tmp/whisper_active_emacs_project",
  project_words_file  = ".whisper_words.txt",

  -- Status icons (SF Symbols)
  icons = {
    idle  = "􀊰",   -- mic
    error = "􁙃"    -- exclamationmark.triangle
  }
}

-- State management
local current_mode     = "casual"
local recordingJob     = nil
local recordingContext = nil
local whisperStatus    = "idle"
local menuIcon         = nil
local iconImages       = {}

-- Animation state
local statusTimer      = nil
local activeVisualizer = nil

-- Logging helper
local function logError(stage, details)
  local f = io.open(config.error_log_file, "a")
  if f then
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    f:write(string.format("[%s] ERROR in %s:\n%s\n\n", timestamp, stage, tostring(details)))
    f:close()
  end
  print("Whisper Error (" .. stage .. "): " .. tostring(details))
end

-- Build static SF Symbol icon images
local function buildIcons()
  for status, char in pairs(config.icons) do
    local c = hs.canvas.new({x=0, y=0, w=22, h=22})
    c[1] = {
      type = "text",
      text = hs.styledtext.new(char, {
        font  = { name = "SF Pro", size = 16 },
        color = { white = 0, alpha = 1 },
        paragraphStyle = { alignment = "center" }
      }),
      frame = { x=0, y=2, w=22, h=20 }
    }
    local img = c:imageFromCanvas()
    c:delete()
    img:template(true)
    iconImages[status] = img
  end
end

local function updateMenu()
  if not menuIcon then return end

  local menu = {
    { title = "Output Mode", disabled = true },
  }

  for _, modeKey in ipairs({"raw", "casual", "tech", "translate", "notes", "email", "message"}) do
    table.insert(menu, {
      title = config.modes[modeKey].title,
      checked = (current_mode == modeKey),
      fn = function()
        current_mode = modeKey
        updateMenu()
      end
    })
  end

  table.insert(menu, { title = "-" })
  table.insert(menu, { title = "Start / Stop & Type  (Cmd+Alt+R)",       disabled = true })
  table.insert(menu, { title = "Start / Stop & Copy  (Cmd+Alt+Shift+R)", disabled = true })
  table.insert(menu, { title = "Cancel  (Shift+Escape)",                 disabled = true })
  table.insert(menu, { title = "-" })
  table.insert(menu, { title = "Status: " .. whisperStatus, disabled = true })

  if whisperStatus == "error" then
    table.insert(menu, { title = "-" })
    table.insert(menu, { title = "Clear Error", fn = function() setStatus("idle") end })
    table.insert(menu, { title = "Open Error Log", fn = function() hs.execute("open " .. config.error_log_file) end })
  end

  menuIcon:setMenu(menu)
end

-- Delegate processing animation to the active visualizer's animate() entry point
local function animateStatusIcon()
  if whisperStatus ~= "transcribing" and whisperStatus ~= "cleaning" then return end
  if activeVisualizer then activeVisualizer.animate() end
end

function setStatus(status)
  whisperStatus = status
  updateMenu()

  if status == "transcribing" or status == "cleaning" then
    if not statusTimer then
      statusTimer = hs.timer.doEvery(0.05, animateStatusIcon)
    end
  else
    if statusTimer then
      statusTimer:stop()
      statusTimer = nil
    end

    if status == "idle" or status == "error" then
      activeVisualizer = nil
    end

    if status ~= "recording" and menuIcon then
      local img = iconImages[status]
      if img then menuIcon:setIcon(img) end
    end
  end
end

-- ============================================================
-- VISUALIZERS
-- ============================================================
-- Switch between visualizations by changing ACTIVE_VISUALIZER.
-- Each factory function returns an object with :start() / :stop().
--
-- Available: "waveform" | "dynamic_island"

local ACTIVE_VISUALIZER = "pulse_dot"

-- Shared: read microphone RMS level from the raw meter file.
-- Returns a smoothed level in [0, 1], updating `state.level` and `state.offset`.
local function updateAudioLevel(state)
  local f = io.open(config.meter_raw_file, "rb")
  if not f then return end
  f:seek("set", state.offset)
  local data = f:read(4000)
  f:close()
  if not (data and #data > 0) then return end
  state.offset = state.offset + #data
  local sum, n = 0, 0
  for i = 1, #data do
    local s = data:byte(i) - 128
    sum = sum + s * s
    n   = n + 1
  end
  if n > 0 then
    local rms = math.sqrt(sum / n) / 128
    if rms < config.meter_noise_gate then rms = 0 end
    local target = math.min(1.0, rms * config.meter_sensitivity)
    if target > state.level then
      state.level = state.level * 0.3 + target * 0.7
    else
      state.level = state.level * 0.85 + target * 0.15
    end
  end
end

-- Shared: start the sox process that writes raw audio to the meter file.
local function startMeterJob(state)
  state.meterJob = hs.task.new(config.sox, function(code, _, stderr)
    if code ~= 0 then logError("Sox Waveform Meter", stderr) end
    state.meterJob = nil
  end, { "--buffer", "800", "-d", "-t", "raw", "-r", "8000", "-c", "1",
         "-e", "unsigned-integer", "-b", "8", config.meter_raw_file })
  state.meterJob:start()
end

-- Shared: tear down sox and the draw timer, remove the raw file.
local function stopMeterJob(state)
  if state.drawTimer then state.drawTimer:stop(); state.drawTimer = nil end
  if state.meterJob  then state.meterJob:terminate(); state.meterJob = nil end
  os.remove(config.meter_raw_file)
  state.level  = 0
  state.offset = 0
end

-- Shared: rolling sine-wave bar animation for transcribing/cleaning.
-- Returns a stateful closure so each visualizer gets its own independent phase.
local function makeSineWaveAnimate()
  local phase = 0
  local num_bars = 6
  local bar_w, gap = 3, 2
  local w, h = 28, 22
  local max_bar_h, min_bar_h = 16, 1
  local startX = (w - (num_bars * bar_w + (num_bars - 1) * gap)) / 2
  local step = (2 * math.pi) / num_bars
  return function()
    phase = phase + 0.10
    local c = hs.canvas.new({x=0, y=0, w=w, h=h})
    for i = 1, num_bars do
      local sine  = (math.sin(phase + (i - 1) * step) + 1) / 2
      local bar_h = min_bar_h + (max_bar_h - min_bar_h) * sine
      c[i] = {
        type = "rectangle",
        fillColor = { black = 1, alpha = 1 },
        strokeColor = { alpha = 0 },
        roundedRectRadii = { xRadius = 1, yRadius = 1 },
        frame = {
          x = startX + (i - 1) * (bar_w + gap),
          y = (h - bar_h) / 2,
          w = bar_w,
          h = bar_h
        }
      }
    end
    local img = c:imageFromCanvas()
    c:delete()
    img:template(true)
    if menuIcon then menuIcon:setIcon(img) end
  end
end

-- ---- Visualizer: Waveform (original 7-bar histogram) ----

local function createWaveformVisualizer()
  local state = { meterJob = nil, drawTimer = nil, level = 0, offset = 0 }

  local weights = {0.2, 0.5, 0.8, 1.0, 0.8, 0.5, 0.2}  -- bell curve, 6 bars outer are shorter
  local num_bars, bar_w, gap = 6, 3, 2
  local w, h = 28, 22
  local max_bar_h = 16
  local startX = (w - (num_bars * bar_w + (num_bars - 1) * gap)) / 2

  local function draw()
    updateAudioLevel(state)
    -- sqrt curve so bars don't saturate at moderate speech levels
    local scaled = math.sqrt(state.level)
    local c = hs.canvas.new({x=0, y=0, w=w, h=h})
    for i = 1, num_bars do
      local bar_h = math.max(1, scaled * max_bar_h * weights[i])
      c[i] = {
        type = "rectangle",
        fillColor = { black = 1, alpha = 1 },
        strokeColor = { alpha = 0 },
        roundedRectRadii = { xRadius = 1, yRadius = 1 },
        frame = {
          x = startX + (i - 1) * (bar_w + gap),
          y = (h - bar_h) / 2,
          w = bar_w,
          h = bar_h
        }
      }
    end
    local img = c:imageFromCanvas()
    c:delete()
    img:template(true)
    if menuIcon then menuIcon:setIcon(img) end
  end

  return {
    start = function()
      startMeterJob(state)
      state.drawTimer = hs.timer.doEvery(0.05, draw)
    end,
    stop    = function() stopMeterJob(state) end,
    animate = makeSineWaveAnimate()
  }
end

-- ---- Visualizer: Dynamic Island (Apple Music-style animated bars) ----
-- Each bar has its own time constant for tracking the global audio level.
-- Fast bars snap up immediately; slow bars lag and linger. At any moment
-- bars are at different stages of reacting, creating independent motion.

local function createDynamicIslandVisualizer()
  local state = { meterJob = nil, drawTimer = nil, level = 0, offset = 0 }

  local num_bars = 6
  local bar_w, gap = 3, 2
  local w, h = 28, 22
  local max_bar_h, min_bar_h = 16, 1
  local startX = (w - (num_bars * bar_w + (num_bars - 1) * gap)) / 2

  -- Non-monotonic time constants so adjacent bars behave differently
  local smooths  = { 0.04, 0.48, 0.08, 0.52, 0.05, 0.22 }
  -- Similar weights so all bars can reach meaningful heights
  local weights  = { 0.68, 0.82, 0.70, 0.85, 0.65, 0.78 }

  local bars = nil

  local function draw()
    updateAudioLevel(state)
    local global_level = state.level

    local c = hs.canvas.new({x=0, y=0, w=w, h=h})
    for i = 1, num_bars do
      local bar = bars[i]

      -- Each bar tracks audio at its own speed
      bar.level = bar.level + (global_level - bar.level) * bar.smooth

      -- Bump scales with bar level so idle barely moves
      bar.ttl = bar.ttl - 1
      if bar.ttl <= 0 then
        bar.bump = (math.random() - 0.5) * 4 * math.sqrt(bar.level + 0.02)
        bar.ttl  = math.random(12, 28)
      end

      local scaled = math.sqrt(bar.level)
      local bar_h = math.max(min_bar_h, math.min(max_bar_h,
        min_bar_h + (max_bar_h - min_bar_h) * scaled * bar.weight + bar.bump))

      bar.current = bar.current + (bar_h - bar.current) * 0.28

      c[i] = {
        type = "rectangle",
        fillColor = { black = 1, alpha = 1 },
        strokeColor = { alpha = 0 },
        roundedRectRadii = { xRadius = 1, yRadius = 1 },
        frame = {
          x = startX + (i - 1) * (bar_w + gap),
          y = (h - bar.current) / 2,
          w = bar_w,
          h = bar.current
        }
      }
    end

    local img = c:imageFromCanvas()
    c:delete()
    img:template(true)
    if menuIcon then menuIcon:setIcon(img) end
  end

  return {
    start = function()
      bars = {}
      for i = 1, num_bars do
        bars[i] = {
          level   = 0,
          current = min_bar_h,
          smooth  = smooths[i],
          weight  = weights[i],
          bump    = 0,
          ttl     = i * 4,
        }
      end
      startMeterJob(state)
      state.drawTimer = hs.timer.doEvery(0.05, draw)
    end,
    stop = function()
      stopMeterJob(state)
      bars = nil
    end,
    animate = makeSineWaveAnimate()
  }
end

-- ---- Visualizer: Frequency Bands (IIR filter bank) ----
-- Cascades 5 single-pole low-pass filters to split the audio into 6 bands.
-- Each bar tracks a true frequency range, so vowels, consonants, and
-- sibilants light up different bars independently.
--
-- Band cutoffs (Hz): 100 | 300 | 700 | 1500 | 3000 | 4000
-- Band assignments:  sub | fund | F1 | F2 | upper-mid | sibilant

local function createFrequencyBandVisualizer()
  local state = { meterJob = nil, drawTimer = nil, offset = 0 }

  local num_bars = 6
  local bar_w, gap = 3, 2
  local w, h = 28, 22
  local max_bar_h, min_bar_h = 16, 1
  local startX = (w - (num_bars * bar_w + (num_bars - 1) * gap)) / 2

  -- alpha = 1 - exp(-2π * fc / fs), fs = 8000 Hz
  -- Cutoffs: 100, 300, 700, 1500, 3000 Hz
  local A = {
    1 - math.exp(-2 * math.pi * 100  / 8000),  -- 0.076
    1 - math.exp(-2 * math.pi * 300  / 8000),  -- 0.209
    1 - math.exp(-2 * math.pi * 700  / 8000),  -- 0.420
    1 - math.exp(-2 * math.pi * 1500 / 8000),  -- 0.697
    1 - math.exp(-2 * math.pi * 3000 / 8000),  -- 0.921
  }

  -- Per-band sensitivity: higher bands need more gain (speech energy falls with frequency)
  local SENS = { 50, 55, 65, 100, 160, 320 }

  local lp          = { 0, 0, 0, 0, 0 }  -- IIR filter state
  local band_level  = { 0, 0, 0, 0, 0, 0 }
  local bars        = nil

  local function readAndProcess()
    local f = io.open(config.meter_raw_file, "rb")
    if not f then return end
    f:seek("set", state.offset)
    local data = f:read(4000)
    f:close()
    if not (data and #data > 0) then return end
    state.offset = state.offset + #data

    local n = #data
    local sum = { 0, 0, 0, 0, 0, 0 }

    for i = 1, n do
      local x = (data:byte(i) - 128) / 128.0  -- normalise to -1..1

      -- Update 5 cascaded low-pass filters
      lp[1] = lp[1] + A[1] * (x     - lp[1])
      lp[2] = lp[2] + A[2] * (x     - lp[2])
      lp[3] = lp[3] + A[3] * (x     - lp[3])
      lp[4] = lp[4] + A[4] * (x     - lp[4])
      lp[5] = lp[5] + A[5] * (x     - lp[5])

      -- Band signals = difference between adjacent LP outputs
      local b1 = lp[1]               -- 0–100 Hz
      local b2 = lp[2] - lp[1]       -- 100–300 Hz  (fundamental)
      local b3 = lp[3] - lp[2]       -- 300–700 Hz  (F1 formant)
      local b4 = lp[4] - lp[3]       -- 700–1500 Hz (F2 formant)
      local b5 = lp[5] - lp[4]       -- 1500–3000 Hz
      local b6 = x    - lp[5]        -- 3000–4000 Hz (sibilants)

      sum[1] = sum[1] + b1*b1
      sum[2] = sum[2] + b2*b2
      sum[3] = sum[3] + b3*b3
      sum[4] = sum[4] + b4*b4
      sum[5] = sum[5] + b5*b5
      sum[6] = sum[6] + b6*b6
    end

    for b = 1, num_bars do
      local rms    = math.sqrt(sum[b] / n)
      local target = math.min(1.0, rms * SENS[b])
      -- Fast attack, slower decay
      if target > band_level[b] then
        band_level[b] = band_level[b] * 0.15 + target * 0.85
      else
        band_level[b] = band_level[b] * 0.70 + target * 0.30
      end
    end
  end

  local function draw()
    readAndProcess()

    local c = hs.canvas.new({x=0, y=0, w=w, h=h})
    for i = 1, num_bars do
      local bar    = bars[i]
      local scaled = math.sqrt(band_level[i])
      local bar_h  = math.max(min_bar_h, min_bar_h + (max_bar_h - min_bar_h) * scaled)
      bar.current  = bar.current + (bar_h - bar.current) * 0.30

      c[i] = {
        type = "rectangle",
        fillColor = { black = 1, alpha = 1 },
        strokeColor = { alpha = 0 },
        roundedRectRadii = { xRadius = 1, yRadius = 1 },
        frame = {
          x = startX + (i - 1) * (bar_w + gap),
          y = (h - bar.current) / 2,
          w = bar_w,
          h = bar.current
        }
      }
    end

    local img = c:imageFromCanvas()
    c:delete()
    img:template(true)
    if menuIcon then menuIcon:setIcon(img) end
  end

  return {
    start = function()
      lp         = { 0, 0, 0, 0, 0 }
      band_level = { 0, 0, 0, 0, 0, 0 }
      bars       = {}
      for i = 1, num_bars do bars[i] = { current = min_bar_h } end
      startMeterJob(state)
      state.drawTimer = hs.timer.doEvery(0.05, draw)
    end,
    stop = function()
      stopMeterJob(state)
      bars = nil
    end,
    animate = makeSineWaveAnimate()
  }
end

-- ---- Visualizer: Pulse Dot ----
-- Single circle whose radius scales with the RMS audio level.
-- Processing animation: slow breathing oscillation.

local function createPulseDotVisualizer()
  local state = { meterJob = nil, drawTimer = nil, level = 0, offset = 0 }
  local w, h  = 22, 22
  local cx, cy = w / 2, h / 2
  local min_r, max_r = 2, 9

  local function drawDot(r)
    local c = hs.canvas.new({x=0, y=0, w=w, h=h})
    c[1] = {
      type        = "oval",
      fillColor   = { black = 1, alpha = 1 },
      strokeColor = { alpha = 0 },
      frame       = { x = cx - r, y = cy - r, w = r * 2, h = r * 2 }
    }
    local img = c:imageFromCanvas()
    c:delete()
    img:template(true)
    if menuIcon then menuIcon:setIcon(img) end
  end

  local animPhase = 0

  return {
    start = function()
      startMeterJob(state)
      state.drawTimer = hs.timer.doEvery(0.05, function()
        updateAudioLevel(state)
        drawDot(min_r + (max_r - min_r) * math.sqrt(state.level))
      end)
    end,
    stop = function()
      stopMeterJob(state)
    end,
    animate = function()
      animPhase = animPhase + 0.10
      -- Hollow ring that breathes between r=1 and r=9 (~3 second cycle)
      local t = (math.sin(animPhase) + 1) / 2
      local r = 1 + 8 * t
      local c = hs.canvas.new({x=0, y=0, w=w, h=h})
      c[1] = {
        type        = "oval",
        fillColor   = { alpha = 0 },
        strokeColor = { black = 1, alpha = 1 },
        strokeWidth = 1.5,
        frame       = { x = cx - r, y = cy - r, w = r * 2, h = r * 2 }
      }
      local img = c:imageFromCanvas()
      c:delete()
      img:template(true)
      if menuIcon then menuIcon:setIcon(img) end
    end
  }
end

-- ---- Visualizer registry ----

local visualizerFactories = {
  waveform         = createWaveformVisualizer,
  dynamic_island   = createDynamicIslandVisualizer,
  frequency_bands  = createFrequencyBandVisualizer,
  pulse_dot        = createPulseDotVisualizer,
}

local function startVisualization()
  local factory = visualizerFactories[ACTIVE_VISUALIZER] or visualizerFactories.waveform
  activeVisualizer = factory()
  activeVisualizer.start()
end

local function stopVisualization()
  if activeVisualizer then
    activeVisualizer.stop()
    -- Keep reference: animate() is called during transcribing/cleaning.
    -- activeVisualizer is cleared by setStatus() on idle/error.
  end
end

-- ============================================================

local function appendWordsFromFile(words, path)
  local f = io.open(path, "r")
  if not f then return end
  for line in f:lines() do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" and not line:match("^#") then table.insert(words, line) end
  end
  f:close()
end

local function loadCustomWords()
  local words = {}
  appendWordsFromFile(words, config.custom_words_file)
  if recordingContext and recordingContext.emacsActive then
    local f = io.open(config.emacs_project_file, "r")
    if f then
      local projectRoot = f:read("*l")
      f:close()
      if projectRoot and projectRoot ~= "" then
        appendWordsFromFile(words, projectRoot .. "/" .. config.project_words_file)
      end
    end
  end
  return words
end

-- Escape a string for safe embedding inside an Elisp double-quoted string.
-- Single quotes are escaped as octal \47 to avoid breaking the shell single-quoting layer.
local function elispEscape(s)
  return s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("'", "\\47"):gsub("\n", "\\n"):gsub("\t", "\\t")
end

-- Run emacsclient --eval synchronously and return the result string
local function emacsEval(expr)
  -- Shell-escape by wrapping in single quotes and escaping embedded single quotes
  local escaped = "'" .. expr:gsub("'", "'\\''") .. "'"
  local cmd = config.emacsclient .. " --eval " .. escaped .. " 2>&1"
  local handle = io.popen(cmd)
  if not handle then
    logError("emacsclient", "failed to popen\ncmd: " .. cmd)
    return nil
  end
  local output = handle:read("*a")
  local ok, exitType, rc = handle:close()
  if not ok then
    logError("emacsclient", "exit " .. tostring(rc) .. ": " .. tostring(output) .. "\ncmd: " .. cmd)
    return nil
  end
  return output and output:match("^%s*(.-)%s*$")
end

-- Create an Emacs marker at point in the user's active buffer (not *server*).
-- Requires whisper-hs.el to be loaded in Emacs. Returns true on success,
-- false if the library is not loaded or emacsclient is unavailable.
local function emacsCreateMarker()
  local result = emacsEval('(condition-case nil (progn (whisper-create-marker) t) (error nil))')
  return result == "t"
end

-- Insert text at the whisper marker via whisper-hs.el.
-- For vterm buffers, uses vterm-send-string instead of insert.
local function emacsInsertAtMarker(text)
  local escaped = elispEscape(text)
  emacsEval(string.format('(whisper-insert "%s")', escaped))
end

-- Delete the whisper marker to avoid leaking.
local function emacsCleanupMarker()
  emacsEval('(whisper-cleanup)')
end

-- Clean up Emacs marker if one exists in the current recording context.
local function cleanupRecordingMarker()
  if recordingContext and recordingContext.emacsMarker then
    emacsCleanupMarker()
  end
end

local function appendToHistory(rawText, cleanedText, language, outputMode, timings, whisperModel, ollamaModel)
  local f = io.open(config.history_file, "a")
  if not f then return end

  local entry = {
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    language = language,
    output_mode = outputMode,
    processing_mode = current_mode,
    whisper_model = whisperModel or config.whisper_model,
    ollama_model = ollamaModel or config.ollama_model,
    raw_text = rawText,
    cleaned_text = cleanedText,
    timings = timings or {}
  }

  local ok, jsonStr = pcall(hs.json.encode, entry)
  if ok then
    f:write(jsonStr .. "\n")
  else
    -- Fallback to plain text if JSON encoding fails
    f:write(string.format("[%s] [%s] [%s] [%s]\nraw: %s\nout: %s\n\n", entry.timestamp, entry.language, entry.output_mode, entry.processing_mode, rawText, cleanedText))
  end
  f:close()
end


local function cleanTranscription(rawText, language, outputMode, callback, timings)
  local useEmacsMarker = recordingContext and recordingContext.emacsMarker and outputMode == "type"
  local cleaningStartTime = hs.timer.absoluteTime()

  if current_mode == "raw" then
    if outputMode == "type" then
      if useEmacsMarker then
        emacsInsertAtMarker(rawText)
      else
        hs.eventtap.keyStrokes(rawText)
      end
    elseif outputMode == "clipboard" then
      hs.pasteboard.setContents(rawText)
    end
    callback(rawText, timings)
    return
  end

  setStatus("cleaning")
  local customWords = loadCustomWords()
  local mode_config = config.modes[current_mode]
  local systemPrompt = (language == "french") and mode_config.system_fr or mode_config.system_en

  if #customWords > 0 then
    local hint = (language == "french") and " Les termes suivants peuvent apparaître : " or " The following terms may appear: "
    systemPrompt = systemPrompt .. hint .. table.concat(customWords, ", ") .. "."
  end

  local payload = {
    model   = config.ollama_model,
    prompt  = rawText,
    system  = systemPrompt,
    stream  = true,
    options = { num_ctx = config.ollama_num_ctx },
    think = false
  }

  local fullCleanedText = ""
  local streamBuffer = ""

  -- This callback processes chunked data from stdout as it arrives
  local streamCallback = function(task, stdout, stderr)
    if stdout then
      streamBuffer = streamBuffer .. stdout
      while true do
        -- Extract one complete line at a time
        local line, rest = streamBuffer:match("^([^\r\n]+)\r?\n(.*)$")
        if not line then break end
        streamBuffer = rest

        -- Safely decode the JSON line
        local ok, parsed = pcall(hs.json.decode, line)
        if ok and parsed and parsed.response then
          fullCleanedText = fullCleanedText .. parsed.response
          if outputMode == "type" and not useEmacsMarker then
            hs.eventtap.keyStrokes(parsed.response)
          end
        end
      end
    end
    return true
  end

  -- Build reproducible curl command for debugging
  local jsonPayload = hs.json.encode(payload)
  local curlCmd = string.format(
    "curl -s -N --max-time 60 -X POST %s -H 'Content-Type: application/json' -d '%s'",
    config.ollama_url, jsonPayload:gsub("'", "'\\''")
  )

  -- Added `--max-time 60` to prevent indefinite hangs
  hs.task.new(config.curl, function(code, stdout, stderr)
    if code ~= 0 then
      logError("Ollama API Request", stderr .. "\nReproduce with:\n" .. curlCmd)
      cleanupRecordingMarker()
      setStatus("error")
      return
    end

    -- Process any lingering text in the buffer that lacked a trailing newline
    if streamBuffer ~= "" then
       local ok, parsed = pcall(hs.json.decode, streamBuffer)
       if ok and parsed and parsed.response then
         fullCleanedText = fullCleanedText .. parsed.response
         if outputMode == "type" and not useEmacsMarker then
           hs.eventtap.keyStrokes(parsed.response)
         end
       end
    end

    -- Trim whitespace for history/clipboard
    fullCleanedText = fullCleanedText:match("^%s*(.-)%s*$") or fullCleanedText

    if useEmacsMarker then
      emacsInsertAtMarker(fullCleanedText)
    elseif outputMode == "clipboard" then
      hs.pasteboard.setContents(fullCleanedText)
    end

    local cleaningEndTime = hs.timer.absoluteTime()
    timings.ollama_cleanup_ms = math.floor((cleaningEndTime - cleaningStartTime) / 1000000)

    callback(fullCleanedText, timings)
  end, streamCallback, {
    "-s", "-N", "--max-time", "60", "-X", "POST", config.ollama_url,
    "-H", "Content-Type: application/json",
    "-d", hs.json.encode(payload)
  }):start()
end

local function stopAndProcess(outputMode)
  -- Stop the meter job (so circle doesn't react to voice during processing)
  -- but keep visualizer reference alive for the animate() function
  if activeVisualizer then activeVisualizer.stop() end

  local speechCaptureEndTime = hs.timer.absoluteTime()
  recordingJob:terminate()
  recordingJob = nil
  setStatus("transcribing")

  local timings = {
    speech_capture_ms = math.floor((speechCaptureEndTime - (recordingContext.startTime or speechCaptureEndTime)) / 1000000)
  }

  local customWords = loadCustomWords()
  local curlArgs = {
    "-s", "--max-time", "60", "-X", "POST", config.whisper_url,
    "-F", "file=@" .. config.recording_file,
    "-F", "response_format=verbose_json"
  }
  if #customWords > 0 then
    table.insert(curlArgs, "-F")
    table.insert(curlArgs, "prompt=" .. table.concat(customWords, ", "))
  end

  -- Build reproducible curl command for debugging
  local whisperCurlCmd = "curl -s --max-time 60 -X POST " .. config.whisper_url
    .. " -F 'file=@" .. config.recording_file .. "'"
    .. " -F 'response_format=verbose_json'"
  if #customWords > 0 then
    whisperCurlCmd = whisperCurlCmd .. " -F 'prompt=" .. table.concat(customWords, ", ") .. "'"
  end

  local whisperStartTime = hs.timer.absoluteTime()
  hs.task.new(config.curl, function(code, stdout, stderr)
    if code ~= 0 then
      logError("Whisper API Request", stderr .. "\nReproduce with:\n" .. whisperCurlCmd)
      cleanupRecordingMarker()
      setStatus("error")
      return
    end

    local whisperEndTime = hs.timer.absoluteTime()
    timings.whisper_transcription_ms = math.floor((whisperEndTime - whisperStartTime) / 1000000)

    local result = hs.json.decode(stdout)
    local text = result and result.text
    if text then
      local language = (result.detected_language or "english"):lower()
      text = text:gsub("\n", " "):gsub("\t", " "):match("^%s*(.-)%s*$")

      cleanTranscription(text, language, outputMode, function(cleanedText, finalTimings)
        appendToHistory(text, cleanedText, language, outputMode, finalTimings, config.whisper_model, config.ollama_model)
        cleanupRecordingMarker()
        hs.notify.new({
          title = "Whisper",
          informativeText = cleanedText,
          withdrawAfter = 5
        }):send()
        setStatus("idle")
      end, timings)
    else
      logError("Whisper JSON Decode", "Failed to parse response: " .. tostring(stdout))
      cleanupRecordingMarker()
      setStatus("error")
    end
  end, curlArgs):start()
end

local function startRecording()
  -- Start audio capture first, before any blocking work, to minimize lost audio at the top.
  recordingJob = hs.task.new(config.sox, function(code, stdout, stderr)
    if code ~= 0 then
      logError("Sox Recording", stderr)
      setStatus("error")
      recordingJob = nil
    end
  end, { "-d", "-r", "16000", "-c", "1", "-e", "signed-integer", "-b", "16", config.recording_file })
  recordingJob:start()

  -- Now do the slower setup (emacsCreateMarker is a blocking io.popen call).
  local frontApp = hs.application.frontmostApplication()
  local isEmacs = frontApp and frontApp:name() == config.emacs_app_name
  recordingContext = {
    emacsActive = isEmacs,
    emacsMarker = false,
    startTime = hs.timer.absoluteTime()
  }

  if isEmacs then
    recordingContext.emacsMarker = emacsCreateMarker()
  end

  setStatus("recording")
  startVisualization()
end

hs.hotkey.bind(config.hotkey_toggle.mods, config.hotkey_toggle.key, function()
  if whisperStatus == "error" then setStatus("idle") end
  -- Prevent State Machine Collisions
  if whisperStatus == "transcribing" or whisperStatus == "cleaning" then return end
  if not recordingJob then startRecording() else stopAndProcess("type") end
end)

hs.hotkey.bind(config.hotkey_stop_copy.mods, config.hotkey_stop_copy.key, function()
  if whisperStatus == "error" then setStatus("idle") end
  -- Prevent State Machine Collisions
  if whisperStatus == "transcribing" or whisperStatus == "cleaning" then return end
  if not recordingJob then startRecording() else stopAndProcess("clipboard") end
end)

hs.hotkey.bind(config.hotkey_cancel.mods, config.hotkey_cancel.key, function()
  if not recordingJob then
    if whisperStatus == "error" then setStatus("idle") end
    return
  end
  stopVisualization()
  recordingJob:terminate()
  recordingJob = nil
  cleanupRecordingMarker()
  recordingContext = nil
  setStatus("idle")
end)

-- Initialize
if menuIcon then menuIcon:delete() end
menuIcon = hs.menubar.new()
buildIcons()
setStatus("idle")
