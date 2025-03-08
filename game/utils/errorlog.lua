-- game/utils/errorlog.lua
-- A dedicated error logging system that writes to the LÖVE save directory
-- This ensures crash logs are available even if the game closes immediately

local ErrorLog = {}

-- Configuration
ErrorLog.enabled = true
ErrorLog.filename = "tfgon_error.log"
ErrorLog.maxLogSize = 500 * 1024 -- 500KB max size
ErrorLog.maxBackups = 3 -- Keep 3 backup files

-- Store a reference to the original error handler
local originalErrorHandler = nil

-- Init counter to track initialization attempts
local initCount = 0

--------------------------------------------------
-- logError: Write an error message to the log file
--------------------------------------------------
function ErrorLog.logError(message, isWarning)
    if not ErrorLog.enabled then return end
    
    -- Ensure the error message is a string
    message = tostring(message or "Unknown error")
    
    -- Create the full log entry with timestamp
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logLevel = isWarning and "WARNING" or "ERROR"
    local entry = string.format("[%s] %s: %s\n", timestamp, logLevel, message)
    
    -- Try to append to the log file
    local success, errorMsg = pcall(function()
        -- Open in append mode
        local file = io.open(ErrorLog.getFullPath(), "a")
        if file then
            file:write(entry)
            file:close()
        end
    end)
    
    -- If io.open failed, try using love.filesystem instead
    if not success then
        pcall(function()
            local content = ""
            
            -- Try to read existing content first
            if love.filesystem.getInfo(ErrorLog.filename) then
                content = love.filesystem.read(ErrorLog.filename) or ""
            end
            
            -- Append new entry and write back
            content = content .. entry
            love.filesystem.write(ErrorLog.filename, content)
        end)
    end
end

--------------------------------------------------
-- logWarning: Log a warning (less severe than error)
--------------------------------------------------
function ErrorLog.logWarning(message)
    ErrorLog.logError(message, true)
end

--------------------------------------------------
-- getFullPath: Get the full path to the error log file
--------------------------------------------------
function ErrorLog.getFullPath()
    -- This gets the save directory path + our log filename
    local saveDirPath = love.filesystem.getSaveDirectory()
    return saveDirPath .. "/" .. ErrorLog.filename
end

--------------------------------------------------
-- rotateLogFile: Rotate log files if they get too large
--------------------------------------------------
function ErrorLog.rotateLogFile()
    -- Check if we need to rotate based on file size
    local info = love.filesystem.getInfo(ErrorLog.filename)
    if info and info.size > ErrorLog.maxLogSize then
        -- Rotate backup files (tfgon_error.log.1, tfgon_error.log.2, etc.)
        for i = ErrorLog.maxBackups, 1, -1 do
            local oldName = ErrorLog.filename .. "." .. (i-1)
            local newName = ErrorLog.filename .. "." .. i
            
            if i == 1 then
                oldName = ErrorLog.filename
            end
            
            if love.filesystem.getInfo(oldName) then
                if love.filesystem.getInfo(newName) then
                    love.filesystem.remove(newName)
                end
                love.filesystem.write(newName, love.filesystem.read(oldName))
            end
        end
        
        -- Create a fresh log file
        love.filesystem.write(ErrorLog.filename, "Log rotated at " .. os.date() .. "\n")
    end
end

--------------------------------------------------
-- customErrorHandler: Our enhanced error handler
--------------------------------------------------
function ErrorLog.customErrorHandler(msg)
    -- First log the error
    ErrorLog.logError("FATAL ERROR: " .. tostring(msg))
    
    -- Add traceback information
    local trace = debug.traceback("Stack trace:", 2)
    ErrorLog.logError("Traceback: " .. trace)
    
    -- Try to log some system information
    local systemInfo = {
        os = love._os or "Unknown OS",
        version = love.getVersion and love.getVersion() or "Unknown LÖVE version",
        initializers = initCount,
        memory = collectgarbage("count") .. " KB",
        time = os.date()
    }
    
    ErrorLog.logError("System information: " .. 
        "OS=" .. systemInfo.os .. ", " ..
        "LÖVE=" .. systemInfo.version .. ", " ..
        "Memory=" .. systemInfo.memory .. ", " ..
        "Init=" .. systemInfo.initializers .. ", " ..
        "Time=" .. systemInfo.time)
    
    -- Try to get a list of loaded modules
    local loadedModules = {}
    for mod, _ in pairs(package.loaded) do
        table.insert(loadedModules, mod)
    end
    
    ErrorLog.logError("Loaded modules: " .. table.concat(loadedModules, ", "))
    
    -- Make sure the log gets written before the game closes
    io.flush()
    
    -- Show alert to the user
    ErrorLog.logError(">>> ERROR LOG WRITTEN TO: " .. ErrorLog.getFullPath())
    
    -- Call the original error handler
    if originalErrorHandler then
        return originalErrorHandler(msg)
    else
        return msg
    end
end

--------------------------------------------------
-- installHandler: Install our custom error handler
--------------------------------------------------
function ErrorLog.installHandler()
    -- Only install once
    if originalErrorHandler then return end
    
    -- Keep track of the original handler
    originalErrorHandler = love.errorhandler or love.errhand
    
    -- Install our custom handler
    love.errorhandler = ErrorLog.customErrorHandler
    
    ErrorLog.logError("Error handler installed at " .. os.date())
end

--------------------------------------------------
-- init: Initialize the error logging system
--------------------------------------------------
function ErrorLog.init()
    initCount = initCount + 1
    ErrorLog.logError("ErrorLog system initialized (" .. initCount .. ")", true)
    ErrorLog.rotateLogFile()
    ErrorLog.installHandler()
    return true
end

-- Automatically initialize when the module is loaded
ErrorLog.init()

return ErrorLog