-- Fake WoW: Forever class trainer. Trainer.Install(W, opts) defines the
-- trainer API on top of Wow.Install(). The visible list holds the services
-- whose type filter is on (headers always show), like the real client.
-- Tests may mutate opts.services after Install; the list is read live.

local Trainer = {}

local state

local function visible()
  local list = {}
  for _, service in ipairs(state.services) do
    if service.type == "header" or state.filters[service.type] then
      list[#list + 1] = service
    end
  end
  return list
end

local function service(i)
  return visible()[i]
end

function Trainer.Install(W, opts)
  state = {
    services = opts.services or {},
    filters = opts.filters or { available = true, unavailable = true, used = true },
    refused = {},
  }
  W.errors = {}
  local def = W.def

  def("GetNumTrainerServices", function()
    return #visible()
  end)
  def("GetTrainerServiceInfo", function(i)
    if state.failOn == i then
      error("trainer row " .. i .. " failed")
    end
    local s = service(i)
    return s.name, s.type, nil, s.level, s.rank, nil
  end)
  def("GetTrainerServiceLevelReq", function(i)
    return service(i).level
  end)
  def("GetTrainerServiceCost", function(i)
    local s = service(i)
    return s.cost or 0, s.isProfession == true
  end)
  def("GetTrainerServiceTypeFilter", function(serviceType)
    return state.filters[serviceType] == true
  end)
  def("SetTrainerServiceTypeFilter", function(serviceType, on)
    if not (on and state.refused[serviceType]) then
      state.filters[serviceType] = on and true or false
    end
    W.broadcast("TRAINER_UPDATE")
  end)
  def("IsTradeskillTrainer", function()
    return opts.tradeskill == true
  end)
  def("geterrorhandler", function()
    return function(message)
      W.errors[#W.errors + 1] = message
    end
  end)
  def("debugstack", function()
    return "stack"
  end)

  rawset(_G, "C_TooltipInfo", {
    GetTrainerService = function(i)
      local s = service(i)
      if s.spellID then
        return { type = 1, id = s.spellID }
      end
    end,
  })
  rawset(_G, "C_Trainer", {
    GetTrainerType = function()
      return opts.trainerType or 0
    end,
  })
  rawset(_G, "Enum", {
    TrainerType = { General = 0, Tradeskills = 2, Pet = 3 },
    TooltipDataType = { Spell = 1 },
  })
end

-- Makes GetTrainerServiceInfo(i) error; nil clears it.
function Trainer.failOn(i)
  state.failOn = i
end

-- Makes SetTrainerServiceTypeFilter(serviceType, true) leave the filter off.
function Trainer.refuse(serviceType)
  state.refused[serviceType] = true
end

return Trainer
