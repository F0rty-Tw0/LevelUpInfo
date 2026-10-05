local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FADE_SECONDS = 0.5

-- One auto-hide countdown for the one window: at most one live timer,
-- the fade is a native AnimationGroup built once in Attach.
local AutoHide = {}

local frame
local db
local fade
local timer

local function cancelTimer()
  if timer then
    timer:Cancel()
    timer = nil
  end
end

local function onExpire()
  timer = nil
  if db.reducedMotion then
    frame:Hide()
  else
    fade:Play()
  end
end

function AutoHide.Pause()
  if not frame then
    return
  end
  cancelTimer()
  fade:Stop()
  frame:SetAlpha(1)
end

function AutoHide.Resume()
  if not frame or not frame:IsShown() or frame:IsMouseOver() then
    return
  end
  cancelTimer()
  timer = _G.C_Timer.NewTimer(db.duration, onExpire)
end

function AutoHide.Close()
  if not frame then
    return
  end
  cancelTimer()
  fade:Stop()
  frame:Hide()
end

function AutoHide.Attach(targetFrame, savedDB)
  frame, db = targetFrame, savedDB
  fade = frame:CreateAnimationGroup()
  local alpha = fade:CreateAnimation("Alpha")
  alpha:SetFromAlpha(1)
  alpha:SetToAlpha(0)
  alpha:SetDuration(FADE_SECONDS)
  fade:SetScript("OnFinished", function()
    frame:Hide()
  end)
  frame:HookScript("OnEnter", AutoHide.Pause)
  frame:HookScript("OnLeave", AutoHide.Resume)
  -- Hiding UIParent (Alt+Z) fires OnHide, which ends the countdown; OnShow restarts it.
  frame:HookScript("OnShow", AutoHide.Resume)
  frame:HookScript("OnHide", function()
    cancelTimer()
    fade:Stop()
  end)
end

ns.AutoHide = AutoHide
return AutoHide
