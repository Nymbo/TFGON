-- game/eventbus.lua
-- A central event bus system for The Fine Game of Nil
-- Implements publish/subscribe pattern to decouple game components
-- Includes integration with Debug utility for better diagnostics
-- UPDATED WITH IMPROVED ERROR HANDLING

local Debug = require("game.utils.debug")
local EventBus = {}

-- Time-related event states
local delayedEvents = {}
local pendingSequences = {}
local lastUpdateTime = 0

-- Standard game events (to ensure consistency and prevent typos)
EventBus.Events = {
    -- Game flow events
    GAME_INITIALIZED = "game:initialized",
    GAME_STARTED = "game:started",
    GAME_ENDED = "game:ended",
    TURN_STARTED = "turn:started",
    TURN_ENDED = "turn:ended",
    
    -- Card events
    CARD_DRAWN = "card:drawn",
    CARD_PLAYED = "card:played",
    CARD_DISCARDED = "card:discarded",
    CARD_ADDED_TO_HAND = "card:addedToHand",
    
    -- Minion events
    MINION_SUMMONED = "minion:summoned",
    MINION_MOVED = "minion:moved",
    MINION_ATTACKED = "minion:attacked",
    MINION_DAMAGED = "minion:damaged",
    MINION_HEALED = "minion:healed",
    MINION_DIED = "minion:died",
    MINION_SELECTED = "minion:selected",
    MINION_DESELECTED = "minion:deselected",
    
    -- Spell events
    SPELL_CAST = "spell:cast",
    SPELL_TARGET_SELECTED = "spell:targetSelected",
    
    -- Weapon events
    WEAPON_EQUIPPED = "weapon:equipped",
    WEAPON_BROKEN = "weapon:broken",
    
    -- Tower events
    TOWER_DAMAGED = "tower:damaged",
    TOWER_DESTROYED = "tower:destroyed",
    
    -- Player events
    PLAYER_MANA_CHANGED = "player:manaChanged",
    PLAYER_HERO_ATTACKED = "player:heroAttacked",
    PLAYER_TURN_STARTED = "player:turnStarted",
    PLAYER_TURN_ENDED = "player:turnEnded",
    
    -- AI events
    AI_TURN_STARTED = "ai:turnStarted",
    AI_TURN_ENDED = "ai:turnEnded",
    AI_ACTION_PERFORMED = "ai:actionPerformed",
    
    -- UI/Input events
    UI_CARD_SELECTED = "ui:cardSelected",
    UI_MINION_SELECTED = "ui:minionSelected",
    UI_BOARD_CLICKED = "ui:boardClicked",
    UI_BUTTON_CLICKED = "ui:buttonClicked",
    UI_DRAGGING_STARTED = "ui:draggingStarted",
    UI_DRAGGING_ENDED = "ui:draggingEnded",
    
    -- Effect events
    EFFECT_TRIGGERED = "effect:triggered",
    BATTLECRY_TRIGGERED = "effect:battlecryTriggered",
    DEATHRATTLE_TRIGGERED = "effect:deathrattleTriggered",
    
    -- Animation events
    ANIMATION_STARTED = "animation:started",
    ANIMATION_COMPLETED = "animation:completed",
    BANNER_DISPLAYED = "animation:bannerDisplayed",
    
    -- Menu/Scene events
    SCENE_CHANGED = "scene:changed",
    SCENE_EXITED = "scene:exited",
    MENU_OPENED = "menu:opened",
    MENU_CLOSED = "menu:closed",
    
    -- Deck events
    DECK_CREATED = "deck:created",
    DECK_MODIFIED = "deck:modified",
    DECK_SELECTED = "deck:selected",
    
    -- Settings events
    SETTINGS_CHANGED = "settings:changed",
    VOLUME_CHANGED = "settings:volumeChanged",
    AI_DIFFICULTY_CHANGED = "settings:aiDifficultyChanged"
}

-- Map of event names to lists of subscriber callbacks
local subscribers = {}

-- Optional debug log of recent events
local eventLog = {}
local MAX_LOG_SIZE = 100
local debugMode = false

-- Queues for different event categories (inspired by Balatro)
local queues = {
    high = {}, -- High priority events (processed first)
    game = {}, -- Core game logic events
    ui = {},   -- UI-related events
    animation = {}, -- Animation-related events
    low = {}   -- Low priority events (processed last)
}
local defaultQueue = "game"

-- Create wrapper objects for event data with common fields
function EventBus.createEventData(additionalData)
    local eventData = additionalData or {}
    eventData.timestamp = love.timer.getTime()
    return eventData
end

-- Helper function to call subscribers of an event
local function callSubscribers(eventName, targetEventName, arg1, arg2, arg3, arg4, arg5)
    if not subscribers[eventName] then
        return
    end
    
    -- Add to call trace if debug is enabled
    if debugMode then
        Debug.addToCallTrace("EventBus: Calling subscribers for " .. targetEventName)
    end
    
    for i, subscriber in pairs(subscribers[eventName]) do
        if subscriber then
            -- Use pcall for improved error handling
            local success, err = pcall(function()
                if eventName == "*" then
                    -- For catch-all subscribers, pass the event name as first parameter
                    subscriber.callback(targetEventName, arg1, arg2, arg3, arg4, arg5)
                else
                    -- For normal subscribers, just pass the parameters
                    subscriber.callback(arg1, arg2, arg3, arg4, arg5)
                end
            end)
            
            if not success then
                Debug.error(string.format("[EventBus] Error in '%s' subscriber for '%s': %s", 
                                    subscriber.name, eventName, tostring(err)))
            end
        end
    end
end

-- Subscribe to an event
function EventBus.subscribe(eventName, callback, subscriberName, priority)
    if not eventName then
        Debug.error("EventBus: Cannot subscribe to nil event name")
        return nil
    end
    
    if not callback or type(callback) ~= "function" then
        Debug.error("EventBus: Callback must be a function")
        return nil
    end
    
    -- Initialize subscriber list for this event if needed
    if not subscribers[eventName] then
        subscribers[eventName] = {}
    end
    
    -- Store the callback with optional subscriber name for debugging
    -- Add priority for controlling execution order (lower runs first)
    table.insert(subscribers[eventName], {
        callback = callback,
        name = subscriberName or "anonymous",
        priority = priority or 50 -- Default medium priority
    })
    
    -- Sort subscribers by priority
    table.sort(subscribers[eventName], function(a, b)
        return (a.priority or 50) < (b.priority or 50)
    end)
    
    if debugMode then
        Debug.info(string.format("[EventBus] '%s' subscribed to event '%s' with priority %d", 
                           subscriberName or "anonymous", eventName, priority or 50))
    end
    
    -- Return a handle that can be used to unsubscribe
    return {
        eventName = eventName,
        index = #subscribers[eventName]
    }
end

-- Unsubscribe using the handle returned from subscribe
function EventBus.unsubscribe(handle)
    if not handle or not handle.eventName or not handle.index then
        Debug.error("EventBus: Invalid unsubscribe handle")
        return false
    end
    
    local eventSubs = subscribers[handle.eventName]
    if not eventSubs then return false end
    
    local subscriberName = eventSubs[handle.index] and eventSubs[handle.index].name
    
    -- Remove subscriber by setting to nil (preserves indices of other subscribers)
    eventSubs[handle.index] = nil
    
    if debugMode then
        Debug.info(string.format("[EventBus] '%s' unsubscribed from event '%s'", 
                           subscriberName or "anonymous", handle.eventName))
    end
    
    return true
end

-- Subscribes to all events (useful for debugging/logging)
function EventBus.subscribeToAll(callback, subscriberName)
    -- Create a special "catch-all" event type
    return EventBus.subscribe("*", callback, subscriberName)
end

-- Publish an event with optional parameters - fixed to use individual args instead of ...
function EventBus.publish(eventName, arg1, arg2, arg3, arg4, arg5)
    if not eventName then
        Debug.error("EventBus: Cannot publish nil event name")
        return
    end
    
    -- Record in event log if debug mode is on
    if debugMode then
        table.insert(eventLog, {
            time = love.timer.getTime(),
            event = eventName,
            params = {arg1, arg2, arg3, arg4, arg5}
        })
        
        -- Keep log size under limit
        if #eventLog > MAX_LOG_SIZE then
            table.remove(eventLog, 1)
        end
        
        Debug.info(string.format("[EventBus] Event '%s' published", eventName))
        
        -- Advanced debugging - dump first argument if it's a table
        if type(arg1) == "table" then
            Debug.info("[EventBus] Event data: " .. Debug.dumpTable(arg1, 0, 1))
        end
    end
    
    -- Use pcall for safer event handling
    local success, err = pcall(function()
        -- Call specific event subscribers
        callSubscribers(eventName, eventName, arg1, arg2, arg3, arg4, arg5)
        
        -- Call catch-all subscribers
        callSubscribers("*", eventName, arg1, arg2, arg3, arg4, arg5)
    end)
    
    if not success then
        Debug.error("[EventBus] Error publishing event '" .. eventName .. "': " .. tostring(err))
    end
end

-- Publish an event to a specific queue (for prioritized handling)
function EventBus.publishToQueue(queueName, eventName, arg1, arg2, arg3, arg4, arg5)
    if not queueName or not queues[queueName] then
        Debug.error("EventBus: Invalid queue name: " .. tostring(queueName))
        return
    end
    
    if not eventName then
        Debug.error("EventBus: Cannot publish nil event name")
        return
    end
    
    -- Store event in the specified queue
    table.insert(queues[queueName], {
        name = eventName,
        params = {arg1, arg2, arg3, arg4, arg5},
        time = love.timer.getTime()
    })
    
    if debugMode then
        Debug.info(string.format("[EventBus] Event '%s' added to queue '%s'", eventName, queueName))
    end
end

-- Publish an event after a delay (in seconds)
function EventBus.publishDelayed(eventName, delay, arg1, arg2, arg3, arg4, arg5)
    if not eventName then
        Debug.error("EventBus: Cannot publish nil event name")
        return
    end
    
    if not delay or type(delay) ~= "number" or delay < 0 then
        Debug.error("EventBus: Delay must be a positive number")
        return
    end
    
    -- Store event with timing information
    table.insert(delayedEvents, {
        name = eventName,
        params = {arg1, arg2, arg3, arg4, arg5},
        publishTime = love.timer.getTime() + delay
    })
    
    if debugMode then
        Debug.info(string.format("[EventBus] Event '%s' scheduled for %.2f seconds from now", 
                           eventName, delay))
    end
end

-- Create and publish a sequence of events with delays between them
function EventBus.publishSequence(sequence)
    if not sequence or type(sequence) ~= "table" or #sequence == 0 then
        Debug.error("EventBus: Sequence must be a non-empty table")
        return
    end
    
    -- Create a new sequence object
    local seq = {
        events = sequence,
        currentIndex = 0,
        startTime = love.timer.getTime(),
        lastEventTime = love.timer.getTime()
    }
    
    table.insert(pendingSequences, seq)
    
    if debugMode then
        Debug.info(string.format("[EventBus] Sequence with %d events created", #sequence))
    end
end

-- Get count of subscribers for an event (useful for debugging)
function EventBus.getSubscriberCount(eventName)
    if not subscribers[eventName] then
        return 0
    end
    
    local count = 0
    for i, s in pairs(subscribers[eventName]) do
        if s then count = count + 1 end
    end
    
    return count
end

-- Process all queues (call in your game's update loop)
function EventBus.update(dt)
    -- Use pcall for safer event processing
    local success, err = pcall(function()
        local currentTime = love.timer.getTime()
        lastUpdateTime = currentTime
        
        -- Process delayed events
        local i = 1
        while i <= #delayedEvents do
            local event = delayedEvents[i]
            if event.publishTime <= currentTime then
                -- Time to publish this event
                local params = event.params
                EventBus.publish(event.name, params[1], params[2], params[3], params[4], params[5])
                table.remove(delayedEvents, i)
            else
                i = i + 1
            end
        end
        
        -- Process event sequences
        i = 1
        while i <= #pendingSequences do
            local seq = pendingSequences[i]
            
            -- Check if it's time for the next event
            local nextIndex = seq.currentIndex + 1
            if nextIndex <= #seq.events then
                local nextEvent = seq.events[nextIndex]
                
                if not nextEvent.delay or currentTime >= seq.lastEventTime + nextEvent.delay then
                    -- Time to publish this event in the sequence
                    local params = nextEvent.params or {}
                    EventBus.publish(nextEvent.name, params[1], params[2], params[3], params[4], params[5])
                    seq.currentIndex = nextIndex
                    seq.lastEventTime = currentTime
                end
                
                i = i + 1
            else
                -- Sequence is completed
                table.remove(pendingSequences, i)
            end
        end
        
        -- Process queues in priority order
        local priorityOrder = {"high", "game", "ui", "animation", "low"}
        for _, queueName in ipairs(priorityOrder) do
            local queue = queues[queueName]
            
            while #queue > 0 do
                local event = table.remove(queue, 1)
                local params = event.params
                
                -- Add trace info for queue processing
                if debugMode and #queue > 5 then
                    Debug.info(string.format("[EventBus] Processing queue '%s' - %d events remaining", 
                                queueName, #queue))
                end
                
                EventBus.publish(event.name, params[1], params[2], params[3], params[4], params[5])
            end
        end
    end)
    
    if not success then
        Debug.error("[EventBus] Error in update: " .. tostring(err))
    end
end

-- Get the number of pending events (useful for waiting for animations)
function EventBus.getPendingEventCount()
    local count = #delayedEvents
    
    for _, queue in pairs(queues) do
        count = count + #queue
    end
    
    for _, seq in ipairs(pendingSequences) do
        count = count + (#seq.events - seq.currentIndex)
    end
    
    return count
end

-- Check if there are any pending events
function EventBus.hasPendingEvents()
    return EventBus.getPendingEventCount() > 0
end

-- Set a specific queue for an event type
function EventBus.setEventQueue(eventName, queueName)
    if not queues[queueName] then
        Debug.error("EventBus: Invalid queue name: " .. tostring(queueName))
        return
    end
    
    -- This will be used when events are published
    -- Implementation would need to be adjusted in publish method
    -- For now, this is just a placeholder for future enhancement
    Debug.warn("EventBus.setEventQueue is not fully implemented yet")
end

-- Toggle debug mode on/off
function EventBus.setDebugMode(enabled)
    debugMode = enabled
    Debug.info("EventBus: Debug mode " .. (enabled and "enabled" or "disabled"))
    return debugMode
end

-- Get event log (if in debug mode)
function EventBus.getEventLog()
    return eventLog
end

-- Clear all subscribers (use with caution, mainly for testing)
function EventBus.clear()
    if debugMode then
        Debug.warn("EventBus: Clearing all subscribers, event logs and pending events")
    end
    
    subscribers = {}
    eventLog = {}
    delayedEvents = {}
    pendingSequences = {}
    
    for queueName, _ in pairs(queues) do
        queues[queueName] = {}
    end
end

-- Get a list of all registered event names (for debugging)
function EventBus.getAllEventNames()
    local eventNames = {}
    for eventName, _ in pairs(subscribers) do
        table.insert(eventNames, eventName)
    end
    return eventNames
end

-- Print diagnostics information about the EventBus
function EventBus.printDiagnostics()
    Debug.info("=== EventBus Diagnostics ===")
    Debug.info("Total event types with subscribers: " .. #EventBus.getAllEventNames())
    
    -- Count total subscribers
    local totalSubscribers = 0
    for _, subs in pairs(subscribers) do
        for _, sub in pairs(subs) do
            if sub then totalSubscribers = totalSubscribers + 1 end
        end
    end
    Debug.info("Total active subscribers: " .. totalSubscribers)
    
    -- Count pending events by type
    Debug.info("Pending events: " .. EventBus.getPendingEventCount())
    Debug.info("- Delayed events: " .. #delayedEvents)
    
    for queueName, queue in pairs(queues) do
        Debug.info("- Queue '" .. queueName .. "': " .. #queue .. " events")
    end
    
    Debug.info("- Sequences: " .. #pendingSequences)
    
    Debug.info("Recent events logged: " .. #eventLog)
    Debug.info("Debug mode: " .. (debugMode and "ON" or "OFF"))
    Debug.info("==========================")
end

-- Initialize the EventBus
Debug.addToCallTrace("EventBus module loaded")
EventBus.setDebugMode(Debug.ENABLED)  -- Link to global debug setting

return EventBus