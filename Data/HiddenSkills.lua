local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ipairs = ipairs

local HiddenSkills = {}

-- Sets entry.hidden (always a boolean) from the hidden-name table; every rank of a name is marked.
function HiddenSkills.Mark(entries, hidden)
  for _, entry in ipairs(entries) do
    entry.hidden = hidden[entry.name] == true
  end
end

ns.HiddenSkills = HiddenSkills
return HiddenSkills
