-- Runs fn with print captured and returns the printed lines. The real print
-- is back before the caller asserts: tests/run.lua prints PASS through it.
return function(fn)
  local lines, real = {}, _G.print
  _G.print = function(text)
    lines[#lines + 1] = text
  end
  local ok, err = pcall(fn)
  _G.print = real
  assert(ok, err)
  return lines
end
