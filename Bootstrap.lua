local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Bootstrap = {}

ns.Bootstrap = Bootstrap
return Bootstrap
