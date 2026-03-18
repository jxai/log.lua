-- test.lua — unit tests for log.lua

local log = require("log")

local passed = 0
local failed = 0

local function assert_eq(label, got, expected)
  if got == expected then
    print("  PASS  " .. label)
    passed = passed + 1
  else
    print("  FAIL  " .. label)
    print("        expected: " .. tostring(expected))
    print("        got:      " .. tostring(got))
    failed = failed + 1
  end
end

local function assert_true(label, v)
  assert_eq(label, not not v, true)
end

local function assert_false(label, v)
  assert_eq(label, not not v, false)
end

-- Capture print output for inspection
local captured = {}
local real_print = print
local function capture_start()
  captured = {}
  print = function(s) captured[#captured + 1] = s end
end
local function capture_stop()
  print = real_print
end


-- ── Helpers ──────────────────────────────────────────────────────────────────

local function reset_log()
  log.level    = "trace"
  log.usecolor = true
  log.outfile  = nil
end

-- Strip ANSI escape codes so we can assert on plain text
local function strip_ansi(s)
  return s:gsub("\27%[%d+m", "")
end


-- ── Suite: level filtering ────────────────────────────────────────────────────

real_print("\n── level filtering ──")

do
  reset_log()
  log.level = "warn"

  capture_start()
  log.trace("t"); log.debug("d"); log.info("i")
  capture_stop()
  assert_eq("levels below threshold produce no output", #captured, 0)

  capture_start()
  log.warn("w"); log.error("e"); log.fatal("f")
  capture_stop()
  assert_eq("levels at/above threshold produce output", #captured, 3)
end

do
  reset_log()
  log.level = "error"

  capture_start()
  log.warn("suppressed")
  capture_stop()
  assert_eq("warn suppressed when level=error", #captured, 0)

  capture_start()
  log.error("shown"); log.fatal("shown")
  capture_stop()
  assert_eq("error and fatal shown when level=error", #captured, 2)
end

do
  reset_log()
  log.level = "trace"

  capture_start()
  for _, fn in ipairs({ "trace", "debug", "info", "warn", "error", "fatal" }) do
    log[fn]("x")
  end
  capture_stop()
  assert_eq("all 6 levels shown when level=trace", #captured, 6)
end


-- ── Suite: output format ──────────────────────────────────────────────────────

real_print("\n── output format ──")

do
  reset_log()
  log.usecolor = false

  capture_start()
  log.info("hello world")
  capture_stop()

  local line = captured[1]
  assert_true("output contains level label INFO", line:find("%[INFO"))
  assert_true("output contains HH:MM:SS timestamp", line:find("%d%d:%d%d:%d%d"))
  assert_true("output contains the message", line:find("hello world"))
  assert_true("output contains source:line", line:find("[^:]+:%d+"))
end

do
  reset_log()
  log.usecolor = true

  capture_start()
  log.warn("colored")
  capture_stop()

  assert_true("ANSI color codes present when usecolor=true",
    captured[1]:find("\27%["))

  log.usecolor = false
  capture_start()
  log.warn("plain")
  capture_stop()

  assert_false("no ANSI codes when usecolor=false",
    captured[1]:find("\27%["))
end

do
  reset_log()
  log.usecolor = false

  -- Each level should use its own uppercased label
  local labels = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL" }
  local fns    = { "trace", "debug", "info", "warn", "error", "fatal" }
  for k, fn in ipairs(fns) do
    capture_start()
    log[fn]("x")
    capture_stop()
    assert_true("level label " .. labels[k], captured[1]:find(labels[k]))
  end
end


-- ── Suite: number rounding ────────────────────────────────────────────────────

real_print("\n── number rounding ──")

do
  reset_log()
  log.usecolor = false

  capture_start()
  log.info(1.23456)
  capture_stop()
  assert_true("float rounded to 2dp", strip_ansi(captured[1]):find("1.23"))
  assert_false("float not printed beyond 2dp", strip_ansi(captured[1]):find("1.2345"))

  capture_start()
  log.info(1.236)
  capture_stop()
  assert_true("float rounds up correctly", strip_ansi(captured[1]):find("1.24"))

  capture_start()
  log.info(-1.23456)
  capture_stop()
  assert_true("negative float rounded to 2dp", strip_ansi(captured[1]):find("-1.23"))
end


-- ── Suite: multi-argument concatenation ──────────────────────────────────────

real_print("\n── multi-argument concatenation ──")

do
  reset_log()
  log.usecolor = false

  capture_start()
  log.info("a", "b", "c")
  capture_stop()
  assert_true("multiple args joined with spaces", captured[1]:find("a b c"))

  capture_start()
  log.info("val:", 42)
  capture_stop()
  assert_true("string and number concatenated", captured[1]:find("val: 42"))
end


-- ── Suite: outfile ────────────────────────────────────────────────────────────

real_print("\n── outfile ──")

do
  local tmpfile = os.tmpname()
  reset_log()
  log.usecolor = false
  log.outfile  = tmpfile

  log.warn("written to file")
  log.outfile = nil -- stop further writes

  local f = assert(io.open(tmpfile, "r"))
  local contents = f:read("*a")
  f:close()
  os.remove(tmpfile)

  assert_true("outfile contains level label", contents:find("WARN"))
  assert_true("outfile contains the message", contents:find("written to file"))
  assert_false("outfile has no ANSI codes", contents:find("\27%["))
end

do
  -- Bad path should raise an error (fail loudly on misconfigured outfile)
  reset_log()
  log.outfile = "/nonexistent_dir/nope.log"
  local ok, err = pcall(function() log.info("safe") end)
  log.outfile = nil
  assert_false("bad outfile path raises an error", ok)
  assert_true("bad outfile error message contains OS reason", err and err:find("No such") ~= nil)
end


-- ── Suite: invalid level ─────────────────────────────────────────────────────

real_print("\n── invalid level ──")

do
  -- setting an invalid level on the global logger raises immediately
  reset_log()
  local ok, err = pcall(function() log.level = "verbose" end)
  reset_log()
  assert_false("invalid level on global logger raises an error", ok)
  assert_true("error message names the invalid value", err and err:find("verbose") ~= nil)
end

do
  -- same check for an instance
  local inst = log { level = "trace" }
  local ok, err = pcall(function() inst.level = "verbose" end)
  assert_false("invalid level on instance raises an error", ok)
  assert_true("instance error message names the invalid value", err and err:find("verbose") ~= nil)
end

do
  -- creating an instance with an invalid level raises immediately
  local ok, err = pcall(function() log { level = "verbose" } end)
  assert_false("log{level='invalid'} raises an error", ok)
  assert_true("creation error message names the invalid value", err and err:find("verbose") ~= nil)
end


-- ── Suite: logger instances ───────────────────────────────────────────────────

real_print("\n── logger instances ──")

do
  -- log is callable and returns a table with all 6 log methods
  local inst = log {}
  assert_eq("log{} returns a table", type(inst), "table")
  for _, fn in ipairs({ "trace", "debug", "info", "warn", "error", "fatal" }) do
    assert_eq("instance has method " .. fn, type(inst[fn]), "function")
  end
end

do
  -- instance level filtering is independent from the global logger
  reset_log()
  log.level = "trace"
  local inst = log { level = "error" }

  capture_start()
  inst.trace("t"); inst.debug("d"); inst.info("i"); inst.warn("w")
  capture_stop()
  assert_eq("instance level=error suppresses trace/debug/info/warn", #captured, 0)

  capture_start()
  inst.error("e"); inst.fatal("f")
  capture_stop()
  assert_eq("instance level=error passes error/fatal", #captured, 2)

  -- global logger must be unaffected
  capture_start()
  log.trace("global logger trace")
  capture_stop()
  assert_eq("global logger level unaffected by instance level", #captured, 1)
end

do
  -- instance inherits global logger defaults when options are omitted
  reset_log()
  log.level    = "warn"
  log.usecolor = false
  local inst   = log {}
  assert_eq("instance inherits level from global logger", inst.level, "warn")
  assert_eq("instance inherits usecolor from global logger", inst.usecolor, false)
  reset_log()
end

do
  -- instance config is isolated: mutating the instance does not affect global logger
  reset_log()
  local inst    = log { level = "trace", usecolor = false }
  inst.level    = "fatal"
  inst.usecolor = true
  assert_eq("global logger level unchanged after instance mutation", log.level, "trace")
  assert_eq("global logger usecolor unchanged after instance mutation", log.usecolor, true)
end

do
  -- instance level is mutable after creation
  reset_log()
  local inst = log { level = "error", usecolor = false }

  capture_start()
  inst.info("before")
  capture_stop()
  assert_eq("info suppressed before level change", #captured, 0)

  inst.level = "info"

  capture_start()
  inst.info("after")
  capture_stop()
  assert_eq("info shown after level lowered to info", #captured, 1)
end

do
  -- instance usecolor is respected
  reset_log()
  local colored = log { usecolor = true, level = "trace" }
  local plain   = log { usecolor = false, level = "trace" }

  capture_start(); colored.info("c"); capture_stop()
  assert_true("instance usecolor=true emits ANSI codes", captured[1]:find("\27%["))

  capture_start(); plain.info("p"); capture_stop()
  assert_false("instance usecolor=false emits no ANSI codes", captured[1]:find("\27%["))
end


-- ── Suite: instance name ──────────────────────────────────────────────────────

real_print("\n── instance name ──")

do
  -- name appears in console output
  reset_log()
  local inst = log { name = "mymod", usecolor = false }

  capture_start()
  inst.info("hello")
  capture_stop()
  assert_true("name appears in console output", captured[1]:find("mymod"))
end

do
  -- global logger output has no name prefix
  reset_log()
  log.usecolor = false

  capture_start()
  log.info("hello")
  capture_stop()
  -- output format is "[INFO  HH:MM:SS] src:line: msg" — nothing before src:line
  assert_true("global logger output matches expected format",
    strip_ansi(captured[1]):match("%[%u+%s+%d+:%d+:%d+%] [^%s]+:%d+:"))
end

do
  -- unnamed instance output has no name prefix either
  reset_log()
  local inst = log { usecolor = false }

  capture_start()
  inst.info("hello")
  capture_stop()
  assert_true("unnamed instance matches same format as global logger",
    strip_ansi(captured[1]):match("%[%u+%s+%d+:%d+:%d+%] [^%s]+:%d+:"))
end

do
  -- name appears in outfile output
  local tmpfile = os.tmpname()
  local inst = log { name = "mymod", usecolor = false, outfile = tmpfile }
  inst.warn("to file")

  local f = assert(io.open(tmpfile, "r"))
  local contents = f:read("*a")
  f:close()
  os.remove(tmpfile)

  assert_true("name appears in outfile output", contents:find("mymod"))
end


-- ── Suite: noop optimization ─────────────────────────────────────────────────

real_print("\n── noop optimization ──")

do
  -- all disabled levels share the same noop function reference
  reset_log()
  log.level = "fatal"
  assert_true("disabled levels share one noop function",
    log.trace == log.debug and log.debug == log.info and
    log.info == log.warn and log.warn == log.error)
  assert_false("enabled level is not the noop", log.trace == log.fatal)
  reset_log()
end

do
  -- after raising the level, newly disabled levels become noop
  reset_log()
  local was_info = log.info -- real impl at level=trace
  log.level = "error"
  assert_false("info becomes noop after level raised to error", log.info == was_info)
  assert_true("info and warn are now the same noop", log.info == log.warn)
  reset_log()
end

do
  -- after lowering the level, previously disabled levels become real again
  reset_log()
  log.level = "fatal"
  local noop_ref = log.info -- captured noop
  log.level = "trace"
  assert_false("info is no longer noop after level lowered to trace", log.info == noop_ref)
  reset_log()
end

do
  -- same noop optimization applies to instances
  local inst = log { level = "warn" }
  assert_true("instance: disabled levels share one noop",
    inst.trace == inst.debug and inst.debug == inst.info)
  assert_false("instance: warn (enabled) is not noop", inst.trace == inst.warn)

  local noop_ref = inst.trace
  inst.level = "trace"
  assert_false("instance: trace is real impl after level lowered", inst.trace == noop_ref)
end


-- ── Summary ──────────────────────────────────────────────────────────────────

real_print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
