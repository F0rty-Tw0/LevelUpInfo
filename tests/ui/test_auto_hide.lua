local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local W
local AutoHide
local frame
local db

-- Fresh fake client, module and plain frame per test (the window comes later).
local function setup()
  W = Wow.Install()
  AutoHide = assert(loadfile("UI/AutoHide.lua"))("LevelUpInfo", {})
  frame = _G.CreateFrame("Frame", nil, _G.UIParent)
  db = { duration = 10, reducedMotion = false }
end

local function attach()
  AutoHide.Attach(frame, db)
end

local function fade()
  return W.state(frame).animationGroups[1]
end

local function test_calls_before_attach_do_nothing()
  setup()
  AutoHide.Pause()
  AutoHide.Resume()
  AutoHide.Close()
  Assert.equal(W.liveTimers, 0)
  Assert.equal(frame:IsShown(), true)
  Assert.equal(W.state(frame).animationGroups, nil)
end

local function test_countdown_uses_duration_then_fades()
  setup()
  attach()
  AutoHide.Resume()
  Assert.equal(W.lastTimerSeconds, 10)
  W.runTimers()
  local animation = W.state(fade()).animations[1]
  Assert.equal(W.state(animation).animationType, "Alpha")
  Assert.equal(W.state(animation).fromAlpha, 1)
  Assert.equal(W.state(animation).toAlpha, 0)
  Assert.equal(W.state(animation).duration, 0.5)
  Assert.equal(fade():IsPlaying(), true)
  Assert.equal(frame:IsShown(), true)
end

local function test_fade_finish_hides_frame()
  setup()
  attach()
  AutoHide.Resume()
  W.runTimers()
  W.finishAnimation(fade())
  Assert.equal(frame:IsShown(), false)
end

local function test_reduced_motion_hides_at_once()
  setup()
  db.reducedMotion = true
  attach()
  AutoHide.Resume()
  W.runTimers()
  Assert.equal(frame:IsShown(), false)
  Assert.equal(fade():IsPlaying(), false)
end

local function test_enter_cancels_timer_and_stops_fade()
  setup()
  attach()
  AutoHide.Resume()
  W.runTimers()
  Assert.equal(frame:GetAlpha(), 0)
  AutoHide.Resume()
  W.fireScript(frame, "OnEnter")
  Assert.equal(frame:GetAlpha(), 1)
  Assert.equal(fade():IsPlaying(), false)
  Assert.equal(W.liveTimers, 0)
end

local function test_leave_restarts_full_countdown_only_when_mouse_is_off()
  setup()
  attach()
  W.mouseOver[frame] = true
  W.fireScript(frame, "OnLeave")
  Assert.equal(W.liveTimers, 0)
  W.mouseOver[frame] = nil
  W.fireScript(frame, "OnLeave")
  Assert.equal(W.liveTimers, 1)
  Assert.equal(W.lastTimerSeconds, 10)
end

local function test_resume_does_nothing_while_hidden()
  setup()
  attach()
  frame:Hide()
  AutoHide.Resume()
  Assert.equal(W.liveTimers, 0)
end

local function test_pause_then_resume_while_hovered_starts_no_countdown()
  setup()
  attach()
  AutoHide.Resume()
  W.runTimers()
  W.mouseOver[frame] = true
  AutoHide.Pause()
  AutoHide.Resume()
  Assert.equal(W.liveTimers, 0)
  Assert.equal(frame:GetAlpha(), 1)
  Assert.equal(fade():IsPlaying(), false)
end

local function test_close_hides_cancels_and_stops_fade()
  setup()
  attach()
  AutoHide.Resume()
  W.runTimers()
  AutoHide.Resume()
  AutoHide.Close()
  Assert.equal(frame:IsShown(), false)
  Assert.equal(W.liveTimers, 0)
  Assert.equal(fade():IsPlaying(), false)
end

local function test_frame_onhide_set_before_attach_still_runs()
  setup()
  local hidden = 0
  frame:SetScript("OnHide", function()
    hidden = hidden + 1
  end)
  attach()
  AutoHide.Resume()
  frame:Hide()
  Assert.equal(hidden, 1)
  Assert.equal(W.liveTimers, 0)
end

local function test_duration_change_applies_to_next_countdown()
  setup()
  attach()
  AutoHide.Resume()
  db.duration = 25
  Assert.equal(W.lastTimerSeconds, 10)
  AutoHide.Resume()
  Assert.equal(W.lastTimerSeconds, 25)
end

local function test_never_more_than_one_live_timer()
  setup()
  attach()
  AutoHide.Resume()
  AutoHide.Resume()
  Assert.equal(W.liveTimers, 1)
end

return function()
  test_calls_before_attach_do_nothing()
  test_countdown_uses_duration_then_fades()
  test_fade_finish_hides_frame()
  test_reduced_motion_hides_at_once()
  test_enter_cancels_timer_and_stops_fade()
  test_leave_restarts_full_countdown_only_when_mouse_is_off()
  test_resume_does_nothing_while_hidden()
  test_pause_then_resume_while_hovered_starts_no_countdown()
  test_close_hides_cancels_and_stops_fade()
  test_frame_onhide_set_before_attach_still_runs()
  test_duration_change_applies_to_next_countdown()
  test_never_more_than_one_live_timer()
end
