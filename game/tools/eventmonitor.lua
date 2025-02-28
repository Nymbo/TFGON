-- game/tools/eventmonitor.lua
-- A development tool for monitoring events flowing through the EventBus
-- Press F9 to toggle the monitor display in-game

local EventBus = require("game/eventbus")
local Debug = require("game/utils/debug")

local EventMonitor = {}

-- Configuration
EventMonitor.isVisible = false  -- Start hidden
EventMonitor.maxEvents = 20     -- Maximum number of events to display
EventMonitor.fontSize = 12      -- Font size for event display
EventMonitor.width = 400        -- Width of the monitor window
EventMonitor.transparency = 0.8 -- Background transparency
EventMonitor.logAllToConsole = false -- Log all events to console
EventMonitor.filters = {}       -- Event type filters

-- State
EventMonitor.recentEvents = {}  -- Circular buffer of recent events
EventMonitor.font = nil         -- Font for display
EventMonitor.enabled = false    -- Is the monitor enabled?
EventMonitor.eventHandler = nil -- Event subscription handle
EventMonitor.scrollOffset = 0   -- Scroll position

-- Initialize the monitor
function EventMonitor.init()
    -- Create font for display
    EventMonitor.font = love.graphics.newFont(EventMonitor.fontSize)
    
    -- Register key press handler for toggle
    if love.keyboard then
        local originalKeyPressed = love.keypressed
        love.keypressed = function(key, scancode, isrepeat)
            if key == "f9" then
                EventMonitor.toggle()
            elseif key == "f10" then
                EventMonitor.logAllToConsole = not EventMonitor.logAllToConsole
                Debug.info("Event logging to console: " .. (EventMonitor.logAllToConsole and "ON" or "OFF"))
            end
            
            if originalKeyPressed then
                originalKeyPressed(key, scancode, isrepeat)
            end
        end
    end
    
    Debug.info("EventMonitor initialized. Press F9 to toggle display.")
end

-- Toggle the monitor on/off
function EventMonitor.toggle()
    EventMonitor.isVisible = not EventMonitor.isVisible
    
    if EventMonitor.isVisible then
        if not EventMonitor.enabled then
            EventMonitor.enable()
        end
        Debug.info("EventMonitor display activated")
    else
        Debug.info("EventMonitor display hidden")
    end
end

-- Enable event monitoring
function EventMonitor.enable()
    if EventMonitor.enabled then return end
    
    -- Subscribe to all events
    EventMonitor.eventHandler = EventBus.subscribeToAll(
        EventMonitor.onEvent,
        "EventMonitor"
    )
    
    -- Enable the event bus debug mode
    EventBus.setDebugMode(true)
    
    EventMonitor.enabled = true
    Debug.info("EventMonitor enabled and listening to all events")
end

-- Disable event monitoring
function EventMonitor.disable()
    if not EventMonitor.enabled then return end
    
    -- Unsubscribe from events
    if EventMonitor.eventHandler then
        EventBus.unsubscribe(EventMonitor.eventHandler)
        EventMonitor.eventHandler = nil
    end
    
    -- Restore event bus debug mode to match Debug.ENABLED
    EventBus.setDebugMode(Debug.ENABLED)
    
    EventMonitor.enabled = false
    Debug.info("EventMonitor disabled")
end

-- Event handler callback
function EventMonitor.onEvent(eventName, ...)
    -- Create timestamp
    local timestamp = os.date("%H:%M:%S")
    
    -- Log to console if option is enabled
    if EventMonitor.logAllToConsole then
        local argStr = ""
        local args = {...}
        for i = 1, #args do
            local arg = args[i]
            if type(arg) == "table" then
                argStr = argStr .. "[table] "
            else
                argStr = argStr .. tostring(arg) .. " "
            end
        end
        
        print(string.format("[Event] %s: %s - %s", timestamp, eventName, argStr))
    end
    
    -- Check filters
    if next(EventMonitor.filters) ~= nil then
        local shouldDisplay = false
        for _, filter in ipairs(EventMonitor.filters) do
            if eventName:match(filter) then
                shouldDisplay = true
                break
            end
        end
        
        if not shouldDisplay then
            return
        end
    end
    
    -- Add to recent events
    table.insert(EventMonitor.recentEvents, 1, {
        time = timestamp,
        name = eventName,
        args = {...}
    })
    
    -- Trim if over the limit
    if #EventMonitor.recentEvents > EventMonitor.maxEvents then
        table.remove(EventMonitor.recentEvents)
    end
end

-- Draw the monitor
function EventMonitor.draw()
    if not EventMonitor.isVisible then
        return
    end
    
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(EventMonitor.font)
    
    -- Calculate position (top-right corner)
    local x = love.graphics.getWidth() - EventMonitor.width - 10
    local y = 10
    
    -- Calculate height based on content
    local lineHeight = EventMonitor.font:getHeight() + 2
    local contentHeight = (#EventMonitor.recentEvents + 2) * lineHeight
    local height = math.min(contentHeight, love.graphics.getHeight() * 0.8)
    
    -- Draw background
    love.graphics.setColor(0, 0, 0, EventMonitor.transparency)
    love.graphics.rectangle("fill", x, y, EventMonitor.width, height)
    
    -- Draw border
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("line", x, y, EventMonitor.width, height)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Event Monitor (F9 to toggle, F10 to log to console)", x + 5, y + 5)
    
    -- Draw event count
    local countText = "Events: " .. #EventMonitor.recentEvents .. 
                      " | Subscribers: " .. EventMonitor.countSubscribers()
    local countWidth = EventMonitor.font:getWidth(countText)
    love.graphics.print(countText, x + EventMonitor.width - countWidth - 5, y + 5)
    
    -- Draw divider
    love.graphics.line(x, y + lineHeight * 1.5, x + EventMonitor.width, y + lineHeight * 1.5)
    
    -- Draw events
    love.graphics.setScissor(x, y + lineHeight * 2, EventMonitor.width, height - lineHeight * 2)
    
    local displayY = y + lineHeight * 2 - EventMonitor.scrollOffset
    for i, event in ipairs(EventMonitor.recentEvents) do
        -- Event time
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print(event.time, x + 5, displayY)
        
        -- Event name
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print(event.name, x + 80, displayY)
        
        -- Event args (simplified)
        local argStr = ""
        for j, arg in ipairs(event.args) do
            if type(arg) == "table" then
                if arg.name then
                    argStr = argStr .. arg.name .. " "
                else
                    argStr = argStr .. "[table] "
                end
            else
                argStr = argStr .. tostring(arg) .. " "
            end
            
            -- Truncate if too long
            if #argStr > 30 then
                argStr = argStr:sub(1, 27) .. "..."
                break
            end
        end
        
        love.graphics.setColor(0.7, 1, 0.7, 1)
        love.graphics.print(argStr, x + 250, displayY)
        
        displayY = displayY + lineHeight
    end
    
    love.graphics.setScissor()
    love.graphics.setFont(oldFont)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Update function
function EventMonitor.update(dt)
    -- Handle scrolling if needed
end

-- Count total number of event subscribers
function EventMonitor.countSubscribers()
    local count = 0
    local events = EventBus.getAllEventNames()
    
    for _, eventName in ipairs(events) do
        count = count + EventBus.getSubscriberCount(eventName)
    end
    
    return count
end

-- Set event filters
function EventMonitor.setFilters(filterPatterns)
    EventMonitor.filters = filterPatterns
    Debug.info("EventMonitor filters set: " .. table.concat(filterPatterns, ", "))
end

-- Clear event filters
function EventMonitor.clearFilters()
    EventMonitor.filters = {}
    Debug.info("EventMonitor filters cleared")
end

-- Handle mouse wheel for scrolling
function EventMonitor.wheelmoved(x, y)
    if EventMonitor.isVisible then
        EventMonitor.scrollOffset = math.max(0, EventMonitor.scrollOffset - y * 20)
        return true
    end
    return false
end

-- Initialize the monitor
EventMonitor.init()

return EventMonitor