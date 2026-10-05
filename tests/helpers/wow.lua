-- Minimal fake WoW API. Wow.Install() rebuilds every global from scratch and
-- returns the state table `W`; tests drive combat, events and scripts
-- through it. W.calls[name] counts calls to any API defined with def().
--
-- Widget state set through C-API-like methods (points, size, shown, ...)
-- lives in widget._stub, never in other top-level fields, so a test can
-- snapshot a Blizzard frame's fields and prove the addon wrote none.

local Wow = {}

local unpack = table.unpack or unpack

-- AnimationGroup: Play jumps the parent's alpha to the end value at once;
-- W.finishAnimation(group) runs OnFinished.
local function newAnimationGroup(parent)
  local stub = { parent = parent, animations = {}, scripts = {}, playing = false }
  local group = { _stub = stub }

  function group:CreateAnimation(animationType)
    local animStub = { animationType = animationType }
    local animation = { _stub = animStub }
    function animation:SetFromAlpha(alpha)
      animStub.fromAlpha = alpha
    end
    function animation:SetToAlpha(alpha)
      animStub.toAlpha = alpha
    end
    function animation:SetDuration(seconds)
      animStub.duration = seconds
    end
    table.insert(stub.animations, animation)
    return animation
  end
  function group:Play()
    stub.playing = true
    for _, animation in ipairs(stub.animations) do
      if animation._stub.toAlpha then
        parent:SetAlpha(animation._stub.toAlpha)
      end
    end
  end
  function group:Stop()
    stub.playing = false
  end
  function group:IsPlaying()
    return stub.playing
  end
  function group:SetScript(script, fn)
    stub.scripts[script] = fn
  end
  return group
end

local function newWidget(W, frameType, name, parent, template)
  local stub = {
    frameType = frameType,
    parent = parent,
    template = template,
    scripts = {},
    hooks = {},
    events = {},
    callbacks = {},
    points = {},
    shown = true,
  }
  local widget = { _stub = stub }

  function widget:SetPoint(...)
    table.insert(stub.points, { ... })
  end
  function widget:GetPoint(index)
    local point = stub.points[index or 1]
    if point then
      return unpack(point)
    end
  end
  function widget:GetNumPoints()
    return #stub.points
  end
  function widget:ClearAllPoints()
    stub.points = {}
  end
  function widget:SetSize(width, height)
    stub.width, stub.height = width, height
  end
  function widget:GetSize()
    return stub.width or 0, stub.height or 0
  end
  function widget:SetHeight(height)
    stub.height = height
  end
  function widget:GetHeight()
    return stub.height or 0
  end
  function widget:SetFrameStrata(strata)
    stub.strata = strata
  end
  function widget:GetFrameStrata()
    return stub.strata
  end
  function widget:EnableMouse(enabled)
    stub.mouse = enabled and true or false
  end
  function widget:IsMouseEnabled()
    return stub.mouse == true
  end
  function widget:SetJustifyH(justify)
    stub.justifyH = justify
  end
  function widget:GetParent()
    return stub.parent
  end
  function widget:SetScript(script, fn)
    stub.scripts[script] = fn
  end
  function widget:GetScript(script)
    return stub.scripts[script]
  end
  function widget:HookScript(script, fn)
    stub.hooks[script] = stub.hooks[script] or {}
    table.insert(stub.hooks[script], fn)
  end
  function widget:RegisterEvent(event)
    stub.events[event] = true
  end
  function widget:UnregisterEvent(event)
    stub.events[event] = nil
  end
  function widget:IsEventRegistered(event)
    return stub.events[event] == true
  end
  -- Like WoW, a visibility change runs OnShow / OnHide (script, then hooks).
  function widget:SetShown(shown)
    shown = shown and true or false
    if stub.shown == shown then
      return
    end
    stub.shown = shown
    local script = shown and "OnShow" or "OnHide"
    if stub.scripts[script] then
      stub.scripts[script](widget)
    end
    for _, fn in ipairs(stub.hooks[script] or {}) do
      fn(widget)
    end
  end
  function widget:Show()
    widget:SetShown(true)
  end
  function widget:Hide()
    widget:SetShown(false)
  end
  function widget:SetEnabled(enabled)
    stub.enabled = enabled and true or false
  end
  function widget:IsEnabled()
    return stub.enabled ~= false
  end
  function widget:IsShown()
    return stub.shown
  end
  function widget:SetText(text)
    stub.text = text
  end
  function widget:GetText()
    return stub.text
  end
  function widget:SetChecked(checked)
    stub.checked = checked and true or false
  end
  function widget:GetChecked()
    return stub.checked == true
  end
  function widget:SetAlpha(alpha)
    stub.alpha = alpha
  end
  function widget:GetAlpha()
    return stub.alpha or 1
  end
  function widget:IsMouseOver()
    return W.mouseOver[widget] == true
  end
  function widget:CreateAnimationGroup()
    local group = newAnimationGroup(widget)
    stub.animationGroups = stub.animationGroups or {}
    table.insert(stub.animationGroups, group)
    return group
  end
  function widget:CreateFontString(fontName, layer, fontTemplate)
    return newWidget(W, "FontString", fontName, widget, fontTemplate)
  end
  function widget:CreateTexture(textureName, layer)
    return newWidget(W, "Texture", textureName, widget)
  end
  function widget:SetTexture(texture)
    stub.texture = texture
  end
  function widget:SetTexCoord(...)
    stub.texCoord = { ... }
  end
  function widget:SetBlendMode(mode)
    stub.blendMode = mode
  end
  function widget:SetAllPoints()
    stub.allPoints = true
  end
  function widget:SetWidth(width)
    stub.width = width
  end
  function widget:SetScale(scale)
    stub.scale = scale
  end
  function widget:GetScale()
    return stub.scale or 1
  end
  function widget:SetMovable(movable)
    stub.movable = movable and true or false
  end
  function widget:RegisterForDrag(...)
    stub.dragButtons = { ... }
  end
  function widget:StartMoving()
    stub.moving = true
  end
  -- Drops the frame at W.dropAt = { point, x, y } (anchored to UIParent).
  function widget:StopMovingOrSizing()
    stub.moving = false
    local drop = W.dropAt
    if drop then
      stub.points = { { drop.point, _G.UIParent, drop.point, drop.x, drop.y } }
    end
  end
  function widget:SetTextColor(r, g, b)
    stub.textColor = { r, g, b }
  end
  -- CallbackRegistry (MinimalSliderWithSteppersTemplate): fn(owner, ...).
  function widget:RegisterCallback(event, fn, owner)
    stub.callbacks[event] = { fn = fn, owner = owner }
  end
  -- MinimalSliderWithSteppersMixin:Init(value, min, max, steps, formatters).
  function widget:Init(value, minValue, maxValue, steps, formatters)
    stub.init = { value = value, min = minValue, max = maxValue, steps = steps, formatters = formatters }
  end

  -- PortraitFrameMixin / TitledPanelMixin and the template's close button.
  if template == "ButtonFrameTemplate" then
    function widget:SetPortraitToUnit(unit)
      stub.portraitUnit = unit
    end
    function widget:SetTitle(title)
      stub.title = title
    end
    widget.CloseButton = newWidget(W, "Button", nil, widget)
  end

  if name then
    rawset(_G, name, widget)
  end
  table.insert(W.frames, widget)
  return widget
end

-- Test-side drivers; they read or poke widget._stub, never other fields.
local function installDrivers(W)
  function W.state(widget)
    return widget._stub
  end

  function W.fireScript(widget, script, ...)
    local stub = widget._stub
    if stub.scripts[script] then
      stub.scripts[script](widget, ...)
    end
    for _, fn in ipairs(stub.hooks[script] or {}) do
      fn(widget, ...)
    end
  end

  function W.fireEvent(widget, event, ...)
    local stub = widget._stub
    if stub.events[event] and stub.scripts.OnEvent then
      stub.scripts.OnEvent(widget, event, ...)
    end
  end

  -- Like the client: fires `event` on every frame registered for it.
  function W.broadcast(event, ...)
    for _, widget in ipairs(W.frames) do
      W.fireEvent(widget, event, ...)
    end
  end

  function W.fireCallback(widget, event, ...)
    local callback = widget._stub.callbacks[event]
    if callback then
      callback.fn(callback.owner, ...)
    end
  end

  -- Calls target[name] the way Blizzard would, then every secure hook on it.
  function W.callHooked(target, name, ...)
    target[name](...)
    for _, hook in ipairs(W.secureHooks[target] and W.secureHooks[target][name] or {}) do
      hook(...)
    end
  end

  -- Fires every timer live right now (not ones started by those callbacks).
  function W.runTimers()
    local due = {}
    for _, timer in ipairs(W.timers) do
      if timer._live then
        due[#due + 1] = timer
      end
    end
    for _, timer in ipairs(due) do
      if timer._live then
        timer._live = false
        W.liveTimers = W.liveTimers - 1
        timer._callback(timer)
      end
    end
  end

  function W.finishAnimation(group)
    local stub = group._stub
    stub.playing = false
    if stub.scripts.OnFinished then
      stub.scripts.OnFinished(group, false)
    end
  end

  function W.snapshot(t)
    local copy = {}
    for key, value in pairs(t) do
      copy[key] = value
    end
    return copy
  end

  -- Keys whose value differs between `t` and an earlier W.snapshot(t).
  function W.changedKeys(t, snapshot)
    local changed = {}
    for key, value in pairs(t) do
      if snapshot[key] ~= value then
        changed[#changed + 1] = tostring(key)
      end
    end
    for key in pairs(snapshot) do
      if t[key] == nil then
        changed[#changed + 1] = tostring(key)
      end
    end
    table.sort(changed)
    return table.concat(changed, ",")
  end
end

function Wow.Install()
  local W = {
    calls = {},
    frames = {},
    secureHooks = {},
    known = {},
    spells = {},
    mouseOver = {},
    timers = {},
    liveTimers = 0,
    healthMax = 100,
    manaMax = 50,
    stats = { 10, 10, 10, 10, 10 },
  }

  local function def(name, fn)
    rawset(_G, name, function(...)
      W.calls[name] = (W.calls[name] or 0) + 1
      return fn(...)
    end)
  end
  W.def = def

  rawset(_G, "MinimalSliderWithSteppersMixin", {
    Label = { Right = 3 },
    Event = { OnValueChanged = "OnValueChanged" },
  })

  def("CreateFrame", function(frameType, name, parent, template)
    return newWidget(W, frameType, name, parent, template)
  end)
  def("CreateMinimalSliderFormatter", function(labelType)
    return function(value)
      return tostring(value) .. "@" .. tostring(labelType)
    end
  end)
  -- Records hooks instead of replacing the field; W.callHooked runs them.
  def("hooksecurefunc", function(target, name, hook)
    if type(target) == "string" then
      target, name, hook = _G, target, name
    end
    assert(type(target[name]) == "function", "hooksecurefunc: no function " .. tostring(name))
    W.secureHooks[target] = W.secureHooks[target] or {}
    W.secureHooks[target][name] = W.secureHooks[target][name] or {}
    table.insert(W.secureHooks[target][name], hook)
  end)
  def("InCombatLockdown", function()
    return W.inCombat == true
  end)
  -- Spellbook: W.known[spellID] = true, W.spells[spellID] = { name, iconID }.
  def("IsPlayerSpell", function(spellID)
    return W.known[spellID] == true
  end)
  rawset(_G, "C_Spell", {
    GetSpellInfo = function(spellID)
      return W.spells[spellID]
    end,
  })
  -- W.liveTimers counts timers neither cancelled nor fired; W.runTimers fires them.
  rawset(_G, "C_Timer", {
    NewTimer = function(seconds, callback)
      local timer = { _live = true, _callback = callback }
      function timer:Cancel()
        if timer._live then
          timer._live = false
          W.liveTimers = W.liveTimers - 1
        end
      end
      W.lastTimerSeconds = seconds
      W.liveTimers = W.liveTimers + 1
      table.insert(W.timers, timer)
      return timer
    end,
  })
  def("wipe", function(t)
    for key in pairs(t) do
      t[key] = nil
    end
    return t
  end)

  def("ButtonFrameTemplate_HideButtonBar", function() end)
  def("GetMoney", function()
    return W.money
  end)
  def("GetMoneyString", function(copper)
    return copper .. "c"
  end)
  def("UnitLevel", function()
    return W.level
  end)
  def("UnitClass", function()
    return "Priest", "PRIEST"
  end)
  def("UnitRace", function()
    return "Undead", "Scourge"
  end)
  def("UnitHealthMax", function()
    return W.healthMax
  end)
  rawset(_G, "Enum", { PowerType = { Mana = 0 } })
  def("UnitPowerMax", function(_unit, powerType)
    if powerType == _G.Enum.PowerType.Mana then
      return W.manaMax
    end
    return 0
  end)
  -- Base and effective value are the same here.
  def("UnitStat", function(_unit, index)
    return W.stats[index], W.stats[index]
  end)
  local function color(r, g, b)
    return {
      GetRGB = function()
        return r, g, b
      end,
    }
  end
  rawset(_G, "RED_FONT_COLOR", color(1, 0.1, 0.1))
  rawset(_G, "HIGHLIGHT_FONT_COLOR", color(1, 1, 1))
  rawset(_G, "HEALTH", "Health")
  rawset(_G, "MANA", "Mana")
  rawset(_G, "TALENT_POINTS", "Talent points")
  for i, stat in ipairs({ "Strength", "Agility", "Stamina", "Intellect", "Spirit" }) do
    rawset(_G, "SPELL_STAT" .. i .. "_NAME", stat)
  end
  -- GameTooltip: the four methods the addon may call, logged in W.tooltip
  -- as { methodName, args... }.
  W.tooltip = {}
  local gameTooltip = {}
  for _, method in ipairs({ "SetOwner", "SetSpellByID", "Show", "Hide" }) do
    gameTooltip[method] = function(_, ...)
      W.tooltip[#W.tooltip + 1] = { method, ... }
    end
  end
  rawset(_G, "GameTooltip", gameTooltip)

  newWidget(W, "Frame", "UIParent")
  installDrivers(W)
  return W
end

return Wow
