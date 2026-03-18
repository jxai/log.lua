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
  for _, fn in ipairs({"trace","debug","info","warn","error","fatal"}) do
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
  assert_true("output contains level label INFO",  line:find("%[INFO"))
  assert_true("output contains HH:MM:SS timestamp", line:find("%d%d:%d%d:%d%d"))
  assert_true("output contains the message",        line:find("hello world"))
  assert_true("output contains source:line",        line:find("[^:]+:%d+"))
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
  local labels = {"TRACE","DEBUG","INFO","WARN","ERROR","FATAL"}
  local fns    = {"trace","debug","info","warn","error","fatal"}
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
  log.outfile = nil  -- stop further writes

  local f = assert(io.open(tmpfile, "r"))
  local contents = f:read("*a")
  f:close()
  os.remove(tmpfile)

  assert_true("outfile contains level label",  contents:find("WARN"))
  assert_true("outfile contains the message",  contents:find("written to file"))
  assert_false("outfile has no ANSI codes",    contents:find("\27%["))
end

do
  -- Bad path should raise an error (fail loudly on misconfigured outfile)
  reset_log()
  log.outfile = "/nonexistent_dir/nope.log"
  local ok = pcall(function() log.info("safe") end)
  log.outfile = nil
  assert_false("bad outfile path raises an error", ok)
end


-- ── Summary ──────────────────────────────────────────────────────────────────

real_print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
