-- game/utils/debug.lua
-- Custom debugging utilities to help catch runtime errors

local Debug = {}

-- Set this to false in production
Debug.ENABLED = true

-- Log levels
Debug.LEVELS = {
    INFO = 1,
    WARNING = 2,
    ERROR = 3,
    CRITICAL = 4
    end

-- Current logging level
Debug.CURRENT_LEVEL = Debug.LEVELS.INFO

-- Call trace history (for tracking execution paths)
Debug.callTrace = {}

-- Error log (for recording errors)
Debug.errorLog = {}

-- Initialize debug mode based on environment
function Debug.init()
    -- Check if we're in development or production
    if love.filesystem.getInfo("debug_mode.txt") then
        Debug.ENABLED = true
    else
        -- Default to enabled while we're fixing syntax errors
        Debug.ENABLED = true
    end
    
    -- Add timestamp to call trace
    Debug.addToCallTrace("Debug system initialized")
end

-- Log a message at specified level
function Debug.log(message, level)
    level = level or Debug.LEVELS.INFO
    
    if not Debug.ENABLED or level < Debug.CURRENT_LEVEL then
        return
    end
    
    local levelNames = {
        [Debug.LEVELS.INFO] = "INFO",
        [Debug.LEVELS.WARNING] = "WARNING",
        [Debug.LEVELS.ERROR] = "ERROR",
        [Debug.LEVELS.CRITICAL] = "CRITICAL"
    end
    
    local timestamp = os.date("%H:%M:%S")
    local logString = string.format("[%s] %s: %s", 
                                   timestamp, 
                                   levelNames[level] or "UNKNOWN", 
                                   tostring(message))
    
    print(logString)
    
    -- Add to error log if this is an error or critical message
    if level >= Debug.LEVELS.ERROR then
        table.insert(Debug.errorLog, {
            timestamp = timestamp,
            level = level,
            message = message
        })
    end
end

-- Log info message
function Debug.info(message)
    Debug.log(message, Debug.LEVELS.INFO)
end

-- Log warning message
function Debug.warn(message)
    Debug.log(message, Debug.LEVELS.WARNING)
end

-- Log error message
function Debug.error(message)
    Debug.log(message, Debug.LEVELS.ERROR)
    
    -- Add to call trace
    Debug.addToCallTrace("ERROR: " .. tostring(message))
end

-- Log critical error message
function Debug.critical(message)
    Debug.log(message, Debug.LEVELS.CRITICAL)
    
    -- Add to call trace
    Debug.addToCallTrace("CRITICAL: " .. tostring(message))
    
    -- In development mode, you might want to raise an error
    if Debug.ENABLED then
        error(message)
    end
end

-- Add an entry to the call trace
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

-- Safe function calling with error handling
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

-- Trace function entry (for tracking execution flow)
function Debug.traceFunction(functionName)
    if not Debug.ENABLED then
        return function() end
    end
    
    Debug.addToCallTrace(functionName .. " - entered")
    return function()
        Debug.addToCallTrace(functionName .. " - exited")
    end
end

-- Function to catch errors and provide detailed reports
function Debug.tryCatch(tryFunc, catchFunc)
    if not Debug.ENABLED then
        -- In production, just run the function normally
        return tryFunc()
    end
    
    local status, result = pcall(tryFunc)
    if not status then
        -- An error occurred
        Debug.error("Caught error: " .. tostring(result))
        
        if type(catchFunc) == "function" then
            return catchFunc(result)
        end
    end
    return result
end

-- Dump table contents for debugging
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

-- Print the call trace (useful for debugging)
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

-- Print error log
function Debug.printErrorLog()
    if #Debug.errorLog == 0 then
        print("Error log is empty")
        return
    end
    
    print("\n=== ERROR LOG ===")
    for i, err in ipairs(Debug.errorLog) do
        local levelNames = {
            [Debug.LEVELS.ERROR] = "ERROR",
            [Debug.LEVELS.CRITICAL] = "CRITICAL"
    end
        print(string.format("%d. [%s] %s: %s", 
                           i, 
                           err.timestamp, 
                           levelNames[err.level] or "UNKNOWN", 
                           tostring(err.message)))
    end
    print("=================\n")
end

-- Check for memory leaks
function Debug.checkMemory()
    local before = collectgarbage("count")
    collectgarbage("collect")
    local after = collectgarbage("count")
    
    Debug.info(string.format("Memory usage: %.1f KB before collection, %.1f KB after (%.1f KB garbage)",
                           before, after, before - after))
end

-- Modify main.lua to include our debugging system
function Debug.installErrorHandler()
    -- Save the original error handler
    local originalErrorHandler = love.errorhandler or love.errhand
    
    -- Create a new error handler that logs errors
    love.errorhandler = function(msg)
        Debug.critical("LOVE Error: " .. tostring(msg))
        Debug.printCallTrace()
        Debug.printErrorLog()
        
        -- Call the original handler
        return originalErrorHandler(msg)
    end
    
    -- Log that we installed the handler
    Debug.info("Debug error handler installed")
end

-- Initialize the debug system
Debug.init()

return Debug