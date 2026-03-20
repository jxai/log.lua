# log.lua

A tiny logging module for Lua.

![screenshot from 2014-07-04 19 55 55](https://cloud.githubusercontent.com/assets/3920290/3484524/2ea2a9c6-03ad-11e4-9ed5-a9744c6fd75d.png)

## Installation

The [log.lua](log.lua?raw=1) file should be dropped into an existing project
and required by it.

```lua
log = require "log"
```

## Usage

log.lua provides 6 functions, each function takes all its arguments,
concatenates them into a string then outputs the string to the console and --
if one is set -- the log file:

- **log.trace(...)**
- **log.debug(...)**
- **log.info(...)**
- **log.warn(...)**
- **log.error(...)**
- **log.fatal(...)**

### Additional options

log.lua provides variables for setting additional options:

#### log.level

The minimum level to log, any logging function called with a lower level than
the `log.level` is ignored and no text is outputted or written. By default this
value is set to `"trace"`, the lowest log level, such that no log messages are
ignored.

The level of each log mode, starting with the lowest log level is as follows:
`"trace"` `"debug"` `"info"` `"warn"` `"error"` `"fatal"`

#### log.usecolor

Whether colors should be used when outputting to the console, this is `true` by
default. If you're using a console which does not support ANSI color escape
codes then this should be disabled.

#### log.outfile

The name of the file where the log should be written, log files do not contain
ANSI colors and always use the full date rather than just the time. By default
`log.outfile` is `nil` (no log file is used). If a file which does not exist is
set as the `log.outfile` then it is created on the first message logged. If the
file already exists it is appended to.

#### log.stderr

Whether to write console output to `stderr` instead of `stdout`. `false` by
default. Useful when the calling program uses stdout for data output and expects
log messages on stderr.

#### log.tostr

A custom function that takes a single value and returns its string
representation, useful when you need richer or domain-specific output. `nil`
by default, falling back to the built-in behavior (number rounding + `tostring`).

An example using [inspect.lua](https://github.com/kikito/inspect.lua):

```lua
local inspect = require "inspect"
log.tostr = function(v) return inspect(v, {newline=" ", indent="", depth=2}) end
log.info({ key = "value" })
-- [INFO  14:32:01] src.lua:2: { key = "value" }
```

## Logger instances

The global logger `log` is also callable and returns a new independent logger
instance with its own configuration. Unspecified options inherit from the
global logger's current values at creation time.

```lua
local logger = log{ name="MyModule", level="warn" }
logger.warn("something went wrong")
-- [WARN  14:32:01] MyModule:src.lua:2: something went wrong
```

### Instance options

#### name

A string label included in each log line to identify the logger. `nil` by
default (no label), as with the global logger. Read-only after creation.

#### level, usecolor, outfile, stderr, tostr

Same semantics as the global options above. They are mutable after creation:

```lua
logger.level = "trace"
logger.usecolor = false
logger.outfile = "app.log"
logger.stderr = true
logger.tostr = function(v)
  if type(v) == "table" then
    -- your own serialization
  end
  return tostring(v)
end
```

## License

This library is free software; you can redistribute it and/or modify it under
the terms of the MIT license. See [LICENSE](LICENSE) for details.
