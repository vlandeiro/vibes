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
  ffmpeg = "/opt/homebrew/bin/ffmpeg",
  curl   = "/usr/bin/curl",

  -- Temp files
  recording_file = "/tmp/whisper_recording.wav",
  fast_file      = "/tmp/whisper_fast.wav",
  meter_raw_file = "/tmp/whisper_meter.raw",

  -- Audio processing
  audio_speed = 1.5,
  whisper_url = "http://127.0.0.1:49440/inference",
  ollama_url  = "http://localhost:49450/api/generate",
  ollama_model = "qwen3.5:9b",
  ollama_num_ctx = 8192,

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
  history_file      = os.getenv("HOME") .. "/.hammerspoon/whisper_history.txt",
  error_log_file    = os.getenv("HOME") .. "/.hammerspoon/whisper_error.log",
  custom_words_file = os.getenv("HOME") .. "/.hammerspoon/whisper_words.txt",

  emacs_app_name      = "Emacs",
  emacs_project_file  = "/tmp/whisper_active_emacs_project",
  project_words_file  = ".whisper_words.txt",

  -- Status icons (SF Symbols)
  icons = {
    idle         = "􀊰",   -- mic
    transcribing = "􀙫",   -- waveform/gear
    cleaning     = "􀻾",   -- pencil
    error        = "􁙃"    -- exclamationmark.triangle
  }
}

-- State management
local current_mode     = "casual"
local recordingJob     = nil
local recordingContext = nil
local whisperStatus    = "idle"
local menuIcon         = nil
local iconImages       = {}
local meterJob         = nil
local waveTimer        = nil
local currentLevel     = 0
local meterOffset      = 0

-- Animation state
local statusTimer      = nil
local statusAnimPhase  = 0

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

-- Animated Progress Bar for Transcribing/Cleaning
local function animateStatusIcon()
  if whisperStatus ~= "transcribing" and whisperStatus ~= "cleaning" then return end

  statusAnimPhase = statusAnimPhase + 0.15
  local char = config.icons[whisperStatus]
  local c = hs.canvas.new({x=0, y=0, w=22, h=22})

  c[1] = {
    type = "text",
    text = hs.styledtext.new(char, {
      font  = { name = "SF Pro", size = 16 },
      color = { white = 0, alpha = 1.0 },
      paragraphStyle = { alignment = "center" }
    }),
    frame = { x=0, y=2, w=22, h=20 }
  }

  local barW = 8
  local max_x = 22 - barW
  local barX = (math.sin(statusAnimPhase) + 1) / 2 * max_x

  c[2] = {
    type = "rectangle",
    fillColor = { black = 1, alpha = 1 },
    strokeColor = { alpha = 0 },
    roundedRectRadii = { xRadius = 1, yRadius = 1 },
    frame = { x = barX, y = 20, w = barW, h = 2 }
  }

  local img = c:imageFromCanvas()
  c:delete()
  img:template(true)
  if menuIcon then menuIcon:setIcon(img) end
end

function setStatus(status)
  whisperStatus = status
  updateMenu()

  if status == "transcribing" or status == "cleaning" then
    if not statusTimer then
      statusAnimPhase = 0
      statusTimer = hs.timer.doEvery(0.05, animateStatusIcon)
    end
  else
    if statusTimer then
      statusTimer:stop()
      statusTimer = nil
    end

    if status ~= "recording" and menuIcon then
      local img = iconImages[status]
      if img then menuIcon:setIcon(img) end
    end
  end
end

-- Waveform: 7-bar histogram
local function redrawWave()
  local f = io.open(config.meter_raw_file, "rb")
  if f then
    f:seek("set", meterOffset)
    local data = f:read(4000)
    f:close()
    if data and #data > 0 then
      meterOffset = meterOffset + #data
      local sum, n = 0, 0
      for i = 1, #data do
        local s = data:byte(i) - 128
        sum = sum + s * s
        n   = n + 1
      end
      if n > 0 then
        local rms = math.sqrt(sum / n) / 128
        if rms < config.meter_noise_gate then rms = 0 end

        local targetLevel = math.min(1.0, rms * config.meter_sensitivity)
        if targetLevel > currentLevel then
            currentLevel = currentLevel * 0.1 + targetLevel * 0.9
        else
            currentLevel = currentLevel * 0.7 + targetLevel * 0.3
        end
      end
    end
  end

  local w, h = 22, 22
  local c = hs.canvas.new({x=0, y=0, w=w, h=h})
  local num_bars = 7
  local weights = {0.2, 0.4, 0.7, 1.0, 0.7, 0.4, 0.2}
  local bar_w = 2
  local gap = 1
  local startX = (w - (num_bars * bar_w + (num_bars - 1) * gap)) / 2

  for i = 1, num_bars do
    local max_bar_h = 16
    local min_bar_h = 1
    local bar_h = math.max(min_bar_h, currentLevel * max_bar_h * weights[i])

    c[i] = {
      type = "rectangle",
      fillColor = { black = 1, alpha = 1 },
      strokeColor = { alpha = 0 },
      roundedRectRadii = { xRadius = 1, yRadius = 1 },
      frame = {
        x = startX + (i - 1) * (bar_w + gap),
        y = (h - bar_h) / 2 + 1,
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

local function startWaveform()
  currentLevel = 0
  meterOffset  = 0
  meterJob = hs.task.new(config.sox, function(code, _, stderr)
    if code ~= 0 then logError("Sox Waveform Meter", stderr) end
    meterJob = nil
  end, { "--buffer", "800", "-d", "-t", "raw", "-r", "8000", "-c", "1", "-e", "unsigned-integer", "-b", "8", config.meter_raw_file })
  meterJob:start()
  waveTimer = hs.timer.doEvery(0.05, redrawWave)
end

local function stopWaveform()
  if waveTimer then waveTimer:stop(); waveTimer = nil end
  if meterJob then meterJob:terminate(); meterJob = nil end
  os.remove(config.meter_raw_file)
  currentLevel = 0
  meterOffset  = 0
end

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

local function appendToHistory(rawText, cleanedText, language, outputMode)
  local f = io.open(config.history_file, "a")
  if not f then return end
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  f:write(string.format("[%s] [%s] [%s] [%s]\nraw: %s\nout: %s\n\n", timestamp, language, outputMode, current_mode, rawText, cleanedText))
  f:close()
end

-- Updated to handle outputMode directly and stream line-by-line
local function cleanTranscription(rawText, language, outputMode, callback)
  if current_mode == "raw" then
    if outputMode == "type" then
      hs.eventtap.keyStrokes(rawText)
    elseif outputMode == "clipboard" then
      hs.pasteboard.setContents(rawText)
    end
    callback(rawText)
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
          -- Instantly type it out if in type mode
          if outputMode == "type" then
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
      setStatus("error")
      return
    end

    -- Process any lingering text in the buffer that lacked a trailing newline
    if streamBuffer ~= "" then
       local ok, parsed = pcall(hs.json.decode, streamBuffer)
       if ok and parsed and parsed.response then
         fullCleanedText = fullCleanedText .. parsed.response
         if outputMode == "type" then
           hs.eventtap.keyStrokes(parsed.response)
         end
       end
    end

    -- Trim whitespace for history/clipboard
    fullCleanedText = fullCleanedText:match("^%s*(.-)%s*$") or fullCleanedText

    if outputMode == "clipboard" then
      hs.pasteboard.setContents(fullCleanedText)
    end

    callback(fullCleanedText)
  end, streamCallback, {
    "-s", "-N", "--max-time", "60", "-X", "POST", config.ollama_url,
    "-H", "Content-Type: application/json",
    "-d", hs.json.encode(payload)
  }):start()
end

local function stopAndProcess(outputMode)
  stopWaveform()
  recordingJob:terminate()
  recordingJob = nil
  setStatus("transcribing")

  hs.task.new(config.ffmpeg, function(code, stdout, stderr)
    if code ~= 0 then
      logError("FFmpeg Speedup", stderr)
      setStatus("error")
      return
    end

    local customWords = loadCustomWords()
    local curlArgs = {
      "-s", "--max-time", "60", "-X", "POST", config.whisper_url,
      "-F", "file=@" .. config.fast_file,
      "-F", "response_format=verbose_json"
    }
    if #customWords > 0 then
      table.insert(curlArgs, "-F")
      table.insert(curlArgs, "prompt=" .. table.concat(customWords, ", "))
    end

    -- Build reproducible curl command for debugging
    local whisperCurlCmd = "curl -s --max-time 60 -X POST " .. config.whisper_url
      .. " -F 'file=@" .. config.fast_file .. "'"
      .. " -F 'response_format=verbose_json'"
    if #customWords > 0 then
      whisperCurlCmd = whisperCurlCmd .. " -F 'prompt=" .. table.concat(customWords, ", ") .. "'"
    end

    hs.task.new(config.curl, function(code, stdout, stderr)
      if code ~= 0 then
        logError("Whisper API Request", stderr .. "\nReproduce with:\n" .. whisperCurlCmd)
        setStatus("error")
        return
      end

      local result = hs.json.decode(stdout)
      local text = result and result.text
      if text then
        local language = (result.detected_language or "english"):lower()
        text = text:gsub("\n", " "):gsub("\t", " "):match("^%s*(.-)%s*$")

        cleanTranscription(text, language, outputMode, function(cleanedText)
          appendToHistory(text, cleanedText, language, outputMode)
          setStatus("idle")
        end)
      else
        logError("Whisper JSON Decode", "Failed to parse response: " .. tostring(stdout))
        setStatus("error")
      end
    end, curlArgs):start()
  end, {
    "-y", "-i", config.recording_file,
    "-filter:a", "atempo=" .. config.audio_speed,
    config.fast_file
  }):start()
end

local function startRecording()
  local frontApp = hs.application.frontmostApplication()
  recordingContext = { emacsActive = frontApp and frontApp:name() == config.emacs_app_name }

  setStatus("recording")

  recordingJob = hs.task.new(config.sox, function(code, stdout, stderr)
    if code ~= 0 then
      logError("Sox Recording", stderr)
      setStatus("error")
      recordingJob = nil
    end
  end, { "-d", config.recording_file })

  recordingJob:start()
  startWaveform()
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
  stopWaveform()
  recordingJob:terminate()
  recordingJob     = nil
  recordingContext = nil
  setStatus("idle")
end)

-- Initialize
if menuIcon then menuIcon:delete() end
menuIcon = hs.menubar.new()
buildIcons()
setStatus("idle")
