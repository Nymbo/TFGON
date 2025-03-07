-- game/utils/debug.lua
-- Custom debugging utilities merged with log.lua-inspired features

local Debug = {}

--------------------------------------------------
-- Configuration
--------------------------------------------------

-- Master switch for debugging; set this to false in production
Debug.ENABLED = true

-- Enables or disables ANSI color codes in console logs
Debug.usecolor = true

-- If set to a string (e.g. "debug.log"), logs will be appended to that file
Debug.outfile = nil

--------------------------------------------------
-- Log Levels
--------------------------------------------------
Debug.LEVELS = {
    INFO     = 1,
    WARNING  = 2,
    ERROR    = 3,
    CRITICAL = 4
}
-- Current logging level
Debug.CURRENT_LEVEL = Debug.LEVELS.INFO

--------------------------------------------------
-- Internal color codes for each level
-- (Extend or change these as you like)
--------------------------------------------------
local levelColors = {
    [Debug.LEVELS.INFO]     = "\27[32m", -- Green
    [Debug.LEVELS.WARNING]  = "\27[33m", -- Yellow
    [Debug.LEVELS.ERROR]    = "\27[31m", -- Red
    [Debug.LEVELS.CRITICAL] = "\27[35m", -- Magenta
}

--------------------------------------------------
-- State / Storage
--------------------------------------------------
-- Call trace history (for tracking execution paths)
Debug.callTrace = {}

-- Error log (for recording errors)
Debug.errorLog = {}

--------------------------------------------------
-- Utility for rounding numbers in logs
--------------------------------------------------
local function round(x, increment)
    increment = increment or 1
    x = x / increment
    if x > 0 then
        return math.floor(x + 0.5) * increment
    else
        return math.ceil(x - 0.5) * increment
    end
end

--------------------------------------------------
-- Enhanced tostring that rounds numbers
--------------------------------------------------
local originalTostring = tostring
local function betterTostring(...)
    local parts = {}
    for i = 1, select('#', ...) do
        local val = select(i, ...)
        if type(val) == "number" then
            -- Round to 2 decimal places
            val = round(val, 0.01)
        end
        parts[#parts + 1] = originalTostring(val)
    end
    return table.concat(parts, " ")
end

--------------------------------------------------
-- Initialize debug mode (checks debug_mode.txt)
--------------------------------------------------
function Debug.init()
    if love.filesystem.getInfo("debug_mode.txt") then
        Debug.ENABLED = true
    else
        -- Default to enabled while we're fixing syntax errors
        Debug.ENABLED = true
    end
    
    Debug.addToCallTrace("Debug system initialized")
end

--------------------------------------------------
-- Master logging function
--------------------------------------------------
function Debug.log(message, level)
    level = level or Debug.LEVELS.INFO
    
    -- Bail out if debug is disabled or level is below the current threshold
    if not Debug.ENABLED or level < Debug.CURRENT_LEVEL then
        return
    end

    local levelNames = {
        [Debug.LEVELS.INFO]     = "INFO",
        [Debug.LEVELS.WARNING]  = "WARNING",
        [Debug.LEVELS.ERROR]    = "ERROR",
        [Debug.LEVELS.CRITICAL] = "CRITICAL"
    }

    -- Convert message(s) to a nicely formatted string
    local msg = betterTostring(message)
    local timestamp = os.date("%H:%M:%S")
    local levelName = levelNames[level] or "UNKNOWN"

    -- Build the console log line
    local consoleLine
    if Debug.usecolor then
        local colorCode = levelColors[level] or ""
        consoleLine = string.format("%s[%s] %s: %s\27[0m", colorCode, timestamp, levelName, msg)
    else
        consoleLine = string.format("[%s] %s: %s", timestamp, levelName, msg)
    end

    -- Print to the console
    print(consoleLine)

    -- If it's an error or above, add to errorLog
    if level >= Debug.LEVELS.ERROR then
        table.insert(Debug.errorLog, {
            timestamp = timestamp,
            level = level,
            message = msg
        })
    end

    -- Optionally write to file
    if Debug.outfile then
        local fp = io.open(Debug.outfile, "a")
        if fp then
            -- Use full date/time in file logs
            local fullDate = os.date()
            local fileLine = string.format("[%s %s] %s\n", fullDate, levelName, msg)
            fp:write(fileLine)
            fp:close()
        end
    end
end

--------------------------------------------------
-- Helper Logging Methods
--------------------------------------------------
function Debug.info(message)
    Debug.log(message, Debug.LEVELS.INFO)
end

function Debug.warn(message)
    Debug.log(message, Debug.LEVELS.WARNING)
end

function Debug.error(message)
    Debug.log(message, Debug.LEVELS.ERROR)
    Debug.addToCallTrace("ERROR: " .. tostring(message))
end

function Debug.critical(message)
    Debug.log(message, Debug.LEVELS.CRITICAL)
    Debug.addToCallTrace("CRITICAL: " .. tostring(message))
    
    -- In dev mode, raise an error
    if Debug.ENABLED then
        error(message)
    end
end

--------------------------------------------------
-- Call Trace
--------------------------------------------------
function Debug.addToCallTrace(functionName)
    if not Debug.ENABLED then
        return
    end
    
    local timestamp = os.date("%H:%M:%S")
    table.insert(Debug.callTrace, {
        time = timestamp,
        name = functionName
    })
    
    -- Keep call trace from growing too large
    if #Debug.callTrace > 100 then
        table.remove(Debug.callTrace, 1)
    end
end

function Debug.printCallTrace()
    if #Debug.callTrace == 0 then
        print("Call trace is empty")
        return
    end
    
    print("\n=== CALL TRACE ===")
    for i, call in ipairs(Debug.callTrace) do
        print(string.format("%d. [%s] %s", i, call.time, call.name))
    end
    print("==================\n")
end

--------------------------------------------------
-- Safe function calling with error handling
--------------------------------------------------
function Debug.safeCall(func, ...)
    if not Debug.ENABLED then
        return func(...)
    end
    
    local args = {...}
    local success, result = pcall(function()
        return func(unpack(args))
    end)
    
    if not success then
        Debug.error("Function call failed: " .. tostring(result))
    end
    
    return result
end

--------------------------------------------------
-- Function entry/exit tracing
--------------------------------------------------
function Debug.traceFunction(functionName)
    if not Debug.ENABLED then
        return function() end
    end
    
    Debug.addToCallTrace(functionName .. " - entered")
    return function()
        Debug.addToCallTrace(functionName .. " - exited")
    end
end

--------------------------------------------------
-- Try/Catch
--------------------------------------------------
function Debug.tryCatch(tryFunc, catchFunc)
    if not Debug.ENABLED then
        return tryFunc()
    end
    
    local status, result = pcall(tryFunc)
    if not status then
        Debug.error("Caught error: " .. tostring(result))
        if type(catchFunc) == "function" then
            return catchFunc(result)
        end
    end
    return result
end

--------------------------------------------------
-- Table Dump
--------------------------------------------------
function Debug.dumpTable(tbl, indent, maxDepth)
    if not Debug.ENABLED then
        return "Debug disabled"
    end
    
    indent = indent or 0
    maxDepth = maxDepth or 3
    
    if indent > maxDepth then
        return "..."
    end
    
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end
    
    local str = "{\n"
    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent + 1)
        if type(v) == "table" then
            str = str .. formatting .. tostring(k) .. " = " ..
                  Debug.dumpTable(v, indent + 1, maxDepth) .. "\n"
        else
            str = str .. formatting .. tostring(k) .. " = " ..
                  tostring(v) .. "\n"
        end
    end
    str = str .. string.rep("  ", indent) .. "}"
    return str
end

--------------------------------------------------
-- Print Error Log
--------------------------------------------------
function Debug.printErrorLog()
    if #Debug.errorLog == 0 then
        print("Error log is empty")
        return
    end
    
    print("\n=== ERROR LOG ===")
    for i, err in ipairs(Debug.errorLog) do
        local levelNames = {
            [Debug.LEVELS.ERROR]    = "ERROR",
            [Debug.LEVELS.CRITICAL] = "CRITICAL"
        }
        print(string.format("%d. [%s] %s: %s",
            i,
            err.timestamp,
            levelNames[err.level] or "UNKNOWN",
            tostring(err.message)))
    end
    print("=================\n")
end

--------------------------------------------------
-- Memory Check
-- Now prints memory usage only once every 5 minutes
--------------------------------------------------
function Debug.checkMemory()
    local currentTime = love.timer.getTime()
    Debug.lastMemoryCheckTime = Debug.lastMemoryCheckTime or 0
    if currentTime - Debug.lastMemoryCheckTime < 300 then
        return
    end
    Debug.lastMemoryCheckTime = currentTime

    local before = collectgarbage("count")
    collectgarbage("collect")
    local after = collectgarbage("count")
    
    Debug.info(string.format("Memory usage: %.1f KB before collection, %.1f KB after (%.1f KB garbage)",
                           before, after, before - after))
end

--------------------------------------------------
-- Install a custom error handler that logs errors
--------------------------------------------------
function Debug.installErrorHandler()
    local originalErrorHandler = love.errorhandler or love.errhand
    
    love.errorhandler = function(msg)
        Debug.critical("LOVE Error: " .. tostring(msg))
        Debug.printCallTrace()
        Debug.printErrorLog()
        
        return originalErrorHandler(msg)
    end
    
    Debug.info("Debug error handler installed")
end

--------------------------------------------------
-- Initialize and return
--------------------------------------------------
Debug.init()
return Debug
