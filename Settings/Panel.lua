local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Defaults = ns.SettingsDefaults or require("LevelUpInfo.Settings.Defaults")
local Localization = ns.Localization or require("LevelUpInfo.Core.Localization")
local SavedState = ns.SavedState or require("LevelUpInfo.Settings.SavedState")

local floor = math.floor
local ipairs = ipairs

local Text = Localization.Text

local CATEGORY_NAME = "LevelUpInfo"
local LEFT = 16
local TOP = -16
local TITLE_HEIGHT = 36
local ROW_HEIGHT = 32
local BOX_SIZE = 26
local LABEL_WIDTH = 200
local SLIDER_WIDTH = 220
local LABEL_GAP = 6
local BUTTON_WIDTH = 140
local BUTTON_HEIGHT = 24
local BUTTON_GAP = 12

-- Canvas page in Options > AddOns. Until the page is first shown only the empty
-- canvas exists; the controls are built once, on that first OnShow.
local Panel = {}

local category
local controls = {}

local function addText(frame, font, text, x, y)
  local label = frame:CreateFontString(nil, "ARTWORK", font)
  label:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
  label:SetJustifyH("LEFT")
  label:SetText(text)
  return label
end

-- Each add* returns a function that shows the saved value in its control.
local function addCheckbox(frame, setting, y, db)
  local box = _G.CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  box:SetSize(BOX_SIZE, BOX_SIZE)
  box:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT, y)
  box:SetHitRectInsets(0, -LABEL_WIDTH, 0, 0)
  addText(frame, "GameFontHighlight", setting.label, LEFT + BOX_SIZE + LABEL_GAP, y - 5)
  local key = setting.key
  box:SetScript("OnClick", function(self)
    db[key] = self:GetChecked() and true or false
  end)
  return function()
    box:SetChecked(db[key])
  end
end

-- Slider values arrive as floats; the saved-state rule snaps them to the setting's step.
local function addSlider(frame, setting, y, db, actions)
  local mixin = _G.MinimalSliderWithSteppersMixin
  local label = addText(frame, "GameFontHighlight", setting.label, LEFT, y - 8)
  label:SetWidth(LABEL_WIDTH)
  local slider = _G.CreateFrame("Frame", nil, frame, "MinimalSliderWithSteppersTemplate")
  slider:SetSize(SLIDER_WIDTH, ROW_HEIGHT)
  slider:SetPoint("LEFT", label, "RIGHT", LABEL_GAP, 0)
  local key = setting.key
  local steps = floor((setting.max - setting.min) / setting.step + 0.5)
  local formatters = { [mixin.Label.Right] = _G.CreateMinimalSliderFormatter(mixin.Label.Right) }
  local function show()
    slider:Init(db[key], setting.min, setting.max, steps, formatters)
  end
  show()
  -- After the first Init, so building never writes a value. Init can fire this
  -- callback again; an unchanged value is ignored.
  slider:RegisterCallback(mixin.Event.OnValueChanged, function(_, value)
    local stepped = SavedState.NormalizeSetting(value, setting)
    if stepped == db[key] then
      return
    end
    db[key] = stepped
    if key == "scale" then
      actions.onScale()
    end
  end, slider)
  return show
end

local function addButton(frame, text, x, y, onClick)
  local button = _G.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
  button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
  button:SetText(text)
  button:SetScript("OnClick", onClick)
  return button
end

local function build(frame, db, actions)
  addText(frame, "GameFontNormalLarge", CATEGORY_NAME, LEFT, TOP)
  local y = TOP - TITLE_HEIGHT
  for _, setting in ipairs(Defaults.list) do
    if setting.kind == "slider" then
      controls[#controls + 1] = addSlider(frame, setting, y, db, actions)
    else
      controls[#controls + 1] = addCheckbox(frame, setting, y, db)
    end
    y = y - ROW_HEIGHT
  end
  addButton(frame, Text("Reset position"), LEFT, y - BUTTON_GAP, actions.onResetPosition)
  addButton(frame, Text("Clear skill data"), LEFT + BUTTON_WIDTH + BUTTON_GAP, y - BUTTON_GAP, function()
    _G.wipe(db.trainers)
  end)
  -- The options window draws above ours, so it closes before the preview shows.
  addButton(frame, Text("Test"), LEFT + 2 * (BUTTON_WIDTH + BUTTON_GAP), y - BUTTON_GAP, function()
    if _G.SettingsPanel then
      _G.HideUIPanel(_G.SettingsPanel)
    end
    actions.onTest()
  end)
end

local function refresh()
  for _, show in ipairs(controls) do
    show()
  end
end

local function restoreDefaults(db, actions)
  for _, setting in ipairs(Defaults.list) do
    db[setting.key] = setting.default
  end
  refresh()
  actions.onScale()
end

-- actions = { onScale = fn, onResetPosition = fn, onTest = fn }; returns the settings category.
function Panel.Register(db, actions)
  controls = {}
  local frame = _G.CreateFrame("Frame")
  local built = false
  frame:SetScript("OnShow", function(self)
    if not built then
      built = true
      build(self, db, actions)
    end
    refresh()
  end)
  frame.OnCommit = function() end
  frame.OnRefresh = refresh
  frame.OnDefault = function()
    restoreDefaults(db, actions)
  end
  category = _G.Settings.RegisterCanvasLayoutCategory(frame, CATEGORY_NAME)
  _G.Settings.RegisterAddOnCategory(category)
  return category
end

function Panel.Open()
  if category then
    _G.Settings.OpenToCategory(category:GetID())
  end
end

ns.SettingsPanel = Panel
return Panel
