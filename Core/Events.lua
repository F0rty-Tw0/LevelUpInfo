local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The addon's one event frame. A handler gets the payload without the event name.
local Events = {}

local handlers = {}

function Events.On(event, handler)
  handlers[event] = handler
  Events.frame:RegisterEvent(event)
end

function Events.Off(event)
  handlers[event] = nil
  Events.frame:UnregisterEvent(event)
end

if _G.CreateFrame then
  Events.frame = _G.CreateFrame("Frame")
  Events.frame:SetScript("OnEvent", function(_self, event, ...)
    local handler = handlers[event]
    if handler then
      handler(...)
    end
  end)
end

ns.Events = Events
return Events
