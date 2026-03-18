--
-- log.lua
--
-- Copyright (c) 2016 rxi
-- Copyright (c) 2026 jxai
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local log = { _version = "0.1.0" }

log.usecolor = true
log.outfile = nil
log.level = "trace"


local modes = {
  { name = "trace", color = "\27[34m", },
  { name = "debug", color = "\27[36m", },
  { name = "info",  color = "\27[32m", },
  { name = "warn",  color = "\27[33m", },
  { name = "error", color = "\27[31m", },
  { name = "fatal", color = "\27[35m", },
}


local levels = {}
for i, v in ipairs(modes) do
  levels[v.name] = i
end


local round = function(x, increment)
  increment = increment or 1
  x = x / increment
  return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end


local _tostring = tostring

local tostring = function(...)
  local t = {}
  for i = 1, select('#', ...) do
    local x = select(i, ...)
    if type(x) == "number" then
      x = round(x, .01)
    end
    t[#t + 1] = _tostring(x)
  end
  return table.concat(t, " ")
end


local function attach_log_methods(instance)
  for i, x in ipairs(modes) do
    local nameupper = x.name:upper()
    instance[x.name] = function(...)
      -- Return early if we're below the log level
      if i < levels[instance.level] then
        return
      end

      local msg = tostring(...)
      local info = debug.getinfo(2, "Sl")
      local lineinfo = info.short_src .. ":" .. info.currentline
      local prefix = instance.name and instance.name .. ":" or ""

      -- Output to console
      print(string.format("%s[%-6s%s]%s %s%s: %s",
        instance.usecolor and x.color or "",
        nameupper,
        os.date("%H:%M:%S"),
        instance.usecolor and "\27[0m" or "",
        prefix,
        lineinfo,
        msg))

      -- Output to log file
      if instance.outfile then
        local fp = io.open(instance.outfile, "a")
        local str = string.format("[%-6s%s] %s%s: %s\n",
          nameupper, os.date(), prefix, lineinfo, msg)
        assert(fp)
        fp:write(str)
        fp:close()
      end
    end
  end
end


-- Attach methods to the global logger, closing over `log` so that mutations
-- like `log.level = "warn"` take effect immediately without recreation.
attach_log_methods(log)


-- Make log callable to create named/customized logger instances.
-- Usage: local logger = log{ name="my logger", level="debug" }
-- Unspecified options inherit from the global values at creation time.
setmetatable(log, {
  __call = function(_, config)
    config = config or {}
    local instance = {
      usecolor = config.usecolor ~= nil and config.usecolor or log.usecolor,
      outfile  = config.outfile ~= nil and config.outfile or log.outfile,
      level    = config.level or log.level,
      name     = config.name,
    }
    attach_log_methods(instance)
    return instance
  end
})


return log
