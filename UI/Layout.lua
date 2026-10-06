local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The window's ordered layout list and the pass that places it. Fills add
-- items; Run stacks them top to bottom with one cursor per container.
-- Item tables are pooled: every field is written on reuse.
local Layout = {}

local items = {}
local count = 0
local cursors = {}

local function nextItem()
  count = count + 1
  local item = items[count] or {}
  items[count] = item
  return item
end

function Layout.Reset()
  count = 0
end

-- `height` nil means the region's own height, read during Run.
function Layout.Add(region, container, x, height)
  local item = nextItem()
  item.region, item.container, item.x, item.height = region, container, x, height
end

function Layout.AddGap(container, height)
  local item = nextItem()
  item.region, item.container, item.x, item.height = nil, container, nil, height
end

-- Places items 1..count; returns the content height and every container's
-- final cursor (one reused table).
function Layout.Run(content)
  _G.wipe(cursors)
  for index = 1, count do
    local item = items[index]
    local container, region = item.container, item.region
    local cursor = cursors[container] or 0
    local height = item.height
    if region then
      region:ClearAllPoints()
      region:SetPoint("TOPLEFT", container, "TOPLEFT", item.x, -cursor)
      region:Show()
      height = height or region:GetHeight()
    end
    cursors[container] = cursor + height
  end
  return cursors[content] or 0, cursors
end

ns.Layout = Layout
return Layout
